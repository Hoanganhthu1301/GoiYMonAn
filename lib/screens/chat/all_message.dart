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

          // Gom tin nhắn theo từng người (mỗi người 1 cuộc hội thoại)
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

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              photoURL != null ? NetworkImage(photoURL) : null,
                          backgroundColor: Colors.orange.withAlpha(150),
                          child: photoURL == null
                              ? Text(displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
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
