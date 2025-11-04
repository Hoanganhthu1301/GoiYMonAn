import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 🔹 Tổng số tin nhắn chưa đọc (hiển thị ở Home)
  Stream<int> unreadCountStream() {
    final user = _auth.currentUser!;
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        if (data['senderId'] != user.uid && !readBy.contains(user.uid)) {
          total++;
        }
      }
      return total;
    });
  }

  // 🔹 Số tin chưa đọc từ 1 người cụ thể (hiển thị trong AllMessages)
  Stream<int> unreadFromUser(String otherUserId) {
    final user = _auth.currentUser!;
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: user.uid)
        .where('senderId', isEqualTo: otherUserId)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(user.uid)) count++;
      }
      return count;
    });
  }

  // 🔹 Đánh dấu đã đọc khi mở chat
  Future<void> markAsRead(String otherUserId) async {
    final user = _auth.currentUser!;
    final query = await _firestore
        .collection('messages')
        .where('participants', arrayContains: user.uid)
        .where('senderId', isEqualTo: otherUserId)
        .get();

    for (var doc in query.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(user.uid)) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([user.uid])
        });
      }
    }
  }
}
