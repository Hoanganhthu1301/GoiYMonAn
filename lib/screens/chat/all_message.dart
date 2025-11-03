import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class AllMessagesScreen extends StatelessWidget {
  const AllMessagesScreen({super.key});

  // Stream realtime số tin nhắn chưa đọc từ một người gửi
  Stream<int> _unreadStream(String otherUserId) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: currentUser.uid)
        .where('senderId', isEqualTo: otherUserId)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(currentUser.uid)) {
          count++;
        }
      }
      return count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tất cả tin nhắn'),
        backgroundColor: Colors.orange,
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

          // Lưu conversation mới nhất theo mỗi người
          final Map<String, Map<String, dynamic>> conversations = {};

          for (var doc in messages) {
            final data = doc.data();
            final otherUserId = (data['participants'] as List)
                .firstWhere((uid) => uid != currentUser.uid);

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
              final time = timestampField != null
                  ? timestampField.toDate()
                  : DateTime.now();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('users').doc(otherUserId).snapshots(),
                builder: (context, userSnapshot) {
                  String displayName = 'Người dùng';
                  String? photoURL;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final data = userSnapshot.data!.data()!;
                    displayName = data['displayName'] ?? 'Người dùng';
                    photoURL = data['photoURL'];
                  }

                  return StreamBuilder<int>(
                    stream: _unreadStream(otherUserId),
                    builder: (context, unreadSnapshot) {
                      final unreadCount = unreadSnapshot.data ?? 0;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoURL != null
                              ? NetworkImage(photoURL)
                              : null,
                          backgroundColor: Colors.orange.withAlpha(150),
                          child: photoURL == null
                              ? Text(displayName.isNotEmpty
                                  ? displayName[0]
                                  : '?')
                              : null,
                        ),
                        title: Text(displayName),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          // Mở chat screen
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: otherUserId,
                              receiverName: displayName,
                            ),
                          ));

                          // Sau khi chat screen đóng, đánh dấu tin nhắn đã đọc
                          
                          
                        },
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
