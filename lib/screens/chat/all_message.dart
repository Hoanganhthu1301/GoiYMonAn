import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/message_service.dart';
import 'chat_screen.dart';

class AllMessagesScreen extends StatelessWidget {
  const AllMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final firestore = FirebaseFirestore.instance;
    final msgSvc = MessageService();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tất cả tin nhắn'),
        backgroundColor: primary,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('messages')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs;

          // Gom tin nhắn theo từng người
          final Map<String, Map<String, dynamic>> conversations = {};

          for (var doc in messages) {
            final data = doc.data();
            final participants = List<String>.from(data['participants']);
            final otherUserId =
                participants.firstWhere((uid) => uid != currentUser.uid);

            if (!conversations.containsKey(otherUserId) ||
                (data['timestamp'] != null &&
                    (conversations[otherUserId]!['timestamp'] == null ||
                        (data['timestamp'] as Timestamp)
                                .compareTo(conversations[otherUserId]!['timestamp']) >
                            0))) {
              conversations[otherUserId] = data;
            }
          }

          final conversationList = conversations.entries.toList()
            ..sort((a, b) {
              final tA = a.value['timestamp'] as Timestamp?;
              final tB = b.value['timestamp'] as Timestamp?;
              if (tA == null && tB == null) return 0;
              if (tA == null) return 1;
              if (tB == null) return -1;
              return tB.compareTo(tA);
            });

          if (conversationList.isEmpty) {
            return const Center(child: Text('Không có tin nhắn nào'));
          }

          return ListView.builder(
            itemCount: conversationList.length,
            itemBuilder: (ctx, index) {
              final convo = conversationList[index];
              final otherUserId = convo.key;
              final lastMessage = convo.value['text'] ?? '';
              final timestampField = convo.value['timestamp'] as Timestamp?;
              final time = timestampField?.toDate() ?? DateTime.now();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('users').doc(otherUserId).snapshots(),
                builder: (context, userSnapshot) {
                  String displayName = 'Người dùng';
                  String? photoURL;

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data()!;
                    displayName = userData['displayName'] ?? 'Người dùng';
                    photoURL = userData['photoURL'];
                  }

                  return StreamBuilder<int>(
                    stream: msgSvc.unreadFromUser(otherUserId),
                    builder: (context, unreadSnapshot) {
                      final unreadCount = unreadSnapshot.data ?? 0;

return Dismissible(
  key: ValueKey(convo.key),
  direction: DismissDirection.endToStart, // Vuốt từ phải sang trái
  background: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: Colors.red,
    child: const Icon(Icons.delete, color: Colors.white),
  ),
  confirmDismiss: (direction) async {
    // Hiện dialog xác nhận xóa
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có muốn xóa cuộc hội thoại này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  },
  onDismissed: (direction) async {
    // Xóa tất cả tin nhắn của conversation này
    final batch = FirebaseFirestore.instance.batch();
    final msgs = await FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var msg in msgs.docs) {
      final participants = List<String>.from(msg['participants']);
      if (participants.contains(convo.key)) {
        batch.delete(msg.reference);
      }
    }

    await batch.commit();
  },
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
    leading: CircleAvatar(
      radius: 24,
      backgroundImage:
          photoURL != null ? NetworkImage(photoURL) : null,
      backgroundColor:
          photoURL == null ? primary.withOpacity(0.2) : Colors.transparent,
      child: photoURL == null
          ? Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  color: primary.darken(), fontWeight: FontWeight.bold),
            )
          : null,
    ),
    title: Text(
      displayName,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16),
    ),
    subtitle: Text(
      lastMessage,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.black87),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$unreadCount',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    ),
    onTap: () async {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: otherUserId,
          receiverName: displayName,
        ),
      ));
      await msgSvc.markAsRead(otherUserId);
    },
  ),
);

                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

extension ColorBrightness on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
