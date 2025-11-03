import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'message_bubble.dart';

class Messages extends StatelessWidget {
  const Messages({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, chatSnapshot) {
        if (chatSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chatDocs = chatSnapshot.data?.docs ?? [];

        return ListView.builder(
          reverse: true,
          itemCount: chatDocs.length,
          itemBuilder: (ctx, index) {
            final doc = chatDocs[index].data();
            final text = doc['text'] as String? ?? '';
            final userId = doc['userId'] as String? ?? 'Unknown';
            final username = doc['username'] as String? ?? 'Ẩn danh';

            final timestampField = doc['createdAt'];
            DateTime time;
            if (timestampField is Timestamp) {
              time = timestampField.toDate();
            } else if (timestampField is DateTime) {
              time = timestampField;
            } else {
              time = DateTime.now();
            }

            final isMe = userId == FirebaseAuth.instance.currentUser?.uid;

            return MessageBubble(
              message: text,
              isMe: isMe,
              userId: userId,
              username: username,
              timestamp: time,
            );
          },
        );
      },
    );
  }
}
