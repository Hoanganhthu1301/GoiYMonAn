import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import logger = require('firebase-functions/logger');
// import * as functions from 'firebase-functions';
import OpenAI from 'openai';

admin.initializeApp();

setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });
logger.info('GOOGLE_CLOUD_PROJECT =', process.env.GOOGLE_CLOUD_PROJECT);
logger.info('FIREBASE_CONFIG =', process.env.FIREBASE_CONFIG);
logger.info('Admin app options =', admin.app().options);


// Initialize OpenAI lazily (moved inside route to avoid startup issues)
function getOpenAIClient(): OpenAI {
  let openai: OpenAI | null = null;

  if (!openai) {
    try {
      const key = process.env.OPENAI_API_KEY;   // ✅ LẤY TỪ ENV VAR

      if (!key) {
        throw new Error('OPENAI_API_KEY env var not set');
      }

      openai = new OpenAI({ apiKey: key });
    } catch (err) {
      logger.error('Failed to initialize OpenAI:', err);
      throw err;
    }
  }
  return openai;
}

// Prompt hệ thống: vai trò trợ lý dinh dưỡng
const SYSTEM_PROMPT = `
Bạn là trợ lý dinh dưỡng AI của ứng dụng tính calo & gợi ý món ăn.
- Giải thích về calo, macro, dinh dưỡng, các chế độ ăn (giảm cân, tăng cân, tăng cơ, ăn chay...).
- Ưu tiên ví dụ món Việt Nam, cách nói dễ hiểu.
- Không khuyến khích giảm cân cực đoan, nguy hiểm.
- Cuối mỗi câu trả lời thêm: "⚠ Thông tin chỉ mang tính tham khảo, không thay thế tư vấn bác sĩ."
`;

// Minimal HTTP API using firebase-functions v2 https onRequest + express
import { onRequest } from 'firebase-functions/v2/https';
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

/**
 * Trigger: push when a notification doc is created under users/{userId}/notifications/{notiId}
 * (Preserve your existing push handler.)
 */
export const sendPushOnNotificationCreate = onDocumentCreated(
  'users/{userId}/notifications/{notiId}',
  async (event) => {
    try {
      const snap = event.data;
      if (!snap) return;

      const { userId } = event.params as { userId: string; notiId: string };
      const data = snap.data() as any;

      // Read tokens list (doc id = token)
      const tSnap = await admin.firestore()
        .collection('users').doc(userId)
        .collection('fcmTokens').get();
      const tokens = tSnap.docs.map(d => d.id).filter(Boolean);
      if (!tokens.length) {
        logger.info(`No FCM tokens for user ${userId}`);
        return;
      }

      // Title/body defaults
      const type = data.type ?? 'general';
      const title = data.title ?? (type === 'like'
        ? 'Bài viết được thích'
        : type === 'follow'
          ? 'Có người theo dõi bạn'
          : 'Thông báo');
      const body = data.body ?? (type === 'like'
        ? `${data.actorName ?? 'Ai đó'} đã thích bài viết của bạn`
        : type === 'follow'
          ? `${data.actorName ?? 'Ai đó'} đã theo dõi bạn`
          : 'Bạn có hoạt động mới');

      // Chunk tokens (max 500 per multicast)
      const chunkSize = 500;
      const chunks: string[][] = [];
      for (let i = 0; i < tokens.length; i += chunkSize) {
        chunks.push(tokens.slice(i, i + chunkSize));
      }

      let totalSuccess = 0;
      let totalFailure = 0;

      for (const chunk of chunks) {
        try {
          const resp = await admin.messaging().sendEachForMulticast({
            notification: { title, body },
            data: {
              type: String(type),
              actorId: data.actorId ? String(data.actorId) : '',
              foodId: data.foodId ? String(data.foodId) : '',
            },
            tokens: chunk,
            android: { priority: 'high', notification: { sound: 'default' } },
            apns: { payload: { aps: { alert: { title, body }, sound: 'default' } } },
          });

          totalSuccess += resp.successCount;
          totalFailure += resp.failureCount;

          // Cleanup invalid tokens in this chunk
          if (resp.failureCount > 0) {
            const batch = admin.firestore().batch();
            resp.responses.forEach((r, i) => {
              if (!r.success) {
                const code = r.error?.code ?? '';
                if (code.includes('registration-token-not-registered') || code.includes('invalid-argument') || code.includes('messaging/invalid-registration-token')) {
                  const tokenId = chunk[i];
                  if (tokenId) {
                    const ref = admin.firestore().collection('users').doc(userId).collection('fcmTokens').doc(tokenId);
                    batch.delete(ref);
                    logger.info(`Deleting invalid token ${tokenId} for user ${userId}`);
                  }
                } else {
                  logger.warn(`FCM error for token index=${i}: ${String(r.error)}`);
                }
              }
            });
            await batch.commit();
          }
        } catch (e) {
          logger.error('FCM chunk send error', e);
        }
      }

      logger.info(`Push sent — tokens=${tokens.length}, success=${totalSuccess}, failure=${totalFailure}`);
    } catch (err) {
      logger.error('sendPushOnNotificationCreate handler error:', err);
    }
  }
);

/**
 * Simple API that ONLY exposes comment endpoints:
 * - GET  /comments?foodId=...&limit=...
 * - POST /comments { foodId, text, replyTo? }
 * - DELETE /comments/:id
 *
 * All endpoints require Firebase ID token in header Authorization: Bearer <idToken>
 */

// Middleware to validate Firebase ID token
async function validateFirebaseIdToken(
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) {
  // Lấy header, trim khoảng trắng 2 đầu
  const authHeader = (req.headers.authorization || '').trim();

  // Kiểm tra "Bearer " không phân biệt hoa/thường
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return res.status(401).json({ error: 'Unauthorized - missing token' });
  }

  // Tách theo khoảng trắng -> an toàn hơn split('Bearer ')
  const parts = authHeader.split(' ');
  const idToken = (parts[1] || '').trim();

  if (!idToken) {
    return res.status(401).json({ error: 'Unauthorized - missing token' });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    (req as any).uid = decoded.uid;
    (req as any).claims = decoded;
    return next();
  } catch (err: any) {
    logger.error(
      'Token verify failed code:',
      err.code,
      'message:',
      err.message
    );
    return res.status(401).json({
      error: 'Unauthorized - invalid token',
      code: err.code || null,
      message: err.message || null,
    });
  }
}



app.use(validateFirebaseIdToken);

// POST /chat-ai  { message, userProfile?, foodList? }
// yêu cầu đã đăng nhập (vì app.use(validateFirebaseIdToken) ở trên)
app.post('/chat-ai', async (req, res) => {
  try {
    const body = req.body || {};
    const message: string = (body.message || '').trim();
    const userProfile = body.userProfile || {};
    const foodList = body.foodList || [];

    if (!message) {
      return res.status(400).json({ error: 'message required' });
    }

    const context = `
Thông tin người dùng:
${JSON.stringify(userProfile, null, 2)}

Danh sách món ăn:
${JSON.stringify(foodList, null, 2)}

Câu hỏi:
${message}
    `;

    const client = getOpenAIClient();
    const completion = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: context },
      ],
      max_tokens: 800,
    });

    const reply =
      completion.choices[0]?.message?.content ??
      'Xin lỗi, tôi đang gặp lỗi khi trả lời. Bạn thử lại nhé.';

    return res.json({ ok: true, reply });
  } catch (err) {
    logger.error('POST /chat-ai error', err);
    return res.status(500).json({ error: 'server_error', details: String(err) });
  }
});

/* ---------- Comments endpoints (only) ---------- */
/**
 * Firestore structure:
 * collection 'comments' documents:
 *  {
 *    foodId: string,
 *    authorId: string,
 *    authorName?: string,
 *    text: string,
 *    replyTo?: string|null,
 *    createdAt: Timestamp
 *  }
 */

// GET /comments?foodId=...&limit=...
app.get('/comments', async (req, res) => {
  const foodId = String(req.query.foodId || '');
  const limit = Math.min(parseInt(String(req.query.limit || '10')) || 10, 200);
  if (!foodId) return res.status(400).json({ error: 'foodId required' });
  try {
    const snap = await admin.firestore().collection('comments')
      .where('foodId', '==', foodId)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();
    const comments = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    return res.json({ ok: true, comments });
  } catch (err) {
    logger.error('GET /comments error', err);
    return res.status(500).json({ error: 'server_error', details: String(err) });
  }
});

// POST /comments { foodId, text, replyTo? }
app.post('/comments', async (req, res) => {
  const uid = (req as any).uid as string;
  const body = req.body || {};
  const foodId = body.foodId && String(body.foodId).trim();
  const text = body.text && String(body.text).trim();
  const replyTo = body.replyTo ? String(body.replyTo) : null;
  if (!foodId || !text) return res.status(400).json({ error: 'foodId and text required' });

  try {
    let authorName: string | null = null;
    try {
      const userRecord = await admin.auth().getUser(uid);
      authorName = userRecord.displayName || userRecord.email || null;
    } catch (_) { /* ignore */ }

    const ref = await admin.firestore().collection('comments').add({
      foodId,
      text,
      authorId: uid,
      authorName,
      replyTo: replyTo || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const newDoc = await ref.get();
    return res.status(201).json({ ok: true, comment: { id: ref.id, ...newDoc.data() } });
  } catch (err) {
    logger.error('POST /comments error', err);
    return res.status(500).json({ error: 'server_error', details: String(err) });
  }
});

// DELETE /comments/:id
app.delete('/comments/:id', async (req, res) => {
  const uid = (req as any).uid as string;
  const claims = (req as any).claims || {};
  const commentId = req.params.id;
  if (!commentId) return res.status(400).json({ error: 'commentId required' });

  try {
    const docRef = admin.firestore().collection('comments').doc(commentId);
    const snap = await docRef.get();
    if (!snap.exists) return res.status(404).json({ error: 'not_found' });
    const data = snap.data() || {};
    const authorId = data.authorId;

    const isAdmin = claims.admin === true || claims.role === 'admin';
    if (authorId !== uid && !isAdmin) return res.status(403).json({ error: 'forbidden' });

    await docRef.delete();
    return res.json({ ok: true });
  } catch (err) {
    logger.error('DELETE /comments error', err);
    return res.status(500).json({ error: 'server_error', details: String(err) });
  }
});

/* ---------- Export Express app as Cloud Function (v2) ---------- */
export const api = onRequest(
  { secrets: ['OPENAI_API_KEY'] },   // 👈 rất quan trọng cho v2
  app
);
