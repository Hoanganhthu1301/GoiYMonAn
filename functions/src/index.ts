import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import logger = require('firebase-functions/logger');

admin.initializeApp();

setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });
logger.info('GOOGLE_CLOUD_PROJECT =', process.env.GOOGLE_CLOUD_PROJECT);
logger.info('FIREBASE_CONFIG =', process.env.FIREBASE_CONFIG);
logger.info('Admin app options =', admin.app().options);

// Minimal HTTP API using firebase-functions v2 https onRequest + express
import { onRequest } from 'firebase-functions/v2/https';
import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

/**
 * Trigger: push when a notification doc is created under users/{userId}/notifications/{notiId}
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

          // Cleanup invalid tokens
          if (resp.failureCount > 0) {
            const batch = admin.firestore().batch();
            resp.responses.forEach((r, i) => {
              if (!r.success) {
                const code = r.error?.code ?? '';
                if (
                  code.includes('registration-token-not-registered') ||
                  code.includes('invalid-argument') ||
                  code.includes('messaging/invalid-registration-token')
                ) {
                  const tokenId = chunk[i];
                  if (tokenId) {
                    const ref = admin.firestore()
                      .collection('users').doc(userId)
                      .collection('fcmTokens').doc(tokenId);
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

/* ---------- Middleware xác thực Firebase ID token ---------- */
async function validateFirebaseIdToken(
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
) {
  const authHeader = (req.headers.authorization || '').trim();

  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return res.status(401).json({ error: 'Unauthorized - missing token' });
  }

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
    logger.error('Token verify failed', err);
    return res.status(401).json({
      error: 'Unauthorized - invalid token',
      code: err.code || null,
      message: err.message || null,
    });
  }
}

app.use(validateFirebaseIdToken);

/* ---------- Comments endpoints ---------- */
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

  if (!foodId || !text) {
    return res.status(400).json({ error: 'foodId and text required' });
  }

  try {
    let authorName: string | null = null;
    try {
      const userRecord = await admin.auth().getUser(uid);
      authorName = userRecord.displayName || userRecord.email || null;
    } catch (_) {}

    const ref = await admin.firestore().collection('comments').add({
      foodId,
      text,
      authorId: uid,
      authorName,
      replyTo: replyTo || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const newDoc = await ref.get();
    return res.status(201).json({
      ok: true,
      comment: { id: ref.id, ...newDoc.data() },
    });
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

  if (!commentId) {
    return res.status(400).json({ error: 'commentId required' });
  }

  try {
    const docRef = admin.firestore().collection('comments').doc(commentId);
    const snap = await docRef.get();
    if (!snap.exists) return res.status(404).json({ error: 'not_found' });

    const data = snap.data() || {};
    const authorId = data.authorId;

    const isAdmin = claims.admin === true || claims.role === 'admin';
    if (authorId !== uid && !isAdmin) {
      return res.status(403).json({ error: 'forbidden' });
    }

    await docRef.delete();
    return res.json({ ok: true });
  } catch (err) {
    logger.error('DELETE /comments error', err);
    return res.status(500).json({ error: 'server_error', details: String(err) });
  }
});

/* ---------- Export Express app as Cloud Function ---------- */
export const api = onRequest(app);
