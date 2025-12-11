import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String? currentUserId;
  final VoidCallback? onDelete;

  const CommentItem({super.key, required this.comment, this.currentUserId, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final text = comment['text'] ?? '';
    final authorName = comment['authorName'] ?? 'Người dùng';
    final authorId = comment['authorId'] ?? '';
    final ts = comment['createdAt'];

    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is Map && ts['_seconds'] != null) {
      time = DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] as int) * 1000);
    } else {
      time = DateTime.now();
    }

    final timeStr = timeago.format(time, locale: 'vi');
    final isOwner = authorId == currentUserId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(text),
          const SizedBox(height: 6),
          Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: isOwner && onDelete != null
          ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 24),
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
