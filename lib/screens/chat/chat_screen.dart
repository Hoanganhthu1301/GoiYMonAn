import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _sendMessage() async {
    final user = _auth.currentUser!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _firestore.collection('messages').add({
      'text': text,
      'senderId': user.uid,
      'receiverId': widget.receiverId,
      'senderName': user.displayName ?? 'Người dùng',
      'timestamp': FieldValue.serverTimestamp(),
      'participants': [user.uid, widget.receiverId],
      'readBy': [user.uid], // người gửi tự đọc
    });

    _controller.clear();
  }

 @override
void initState() {
  super.initState();
  // Khi màn hình chat vừa build xong, đánh dấu tất cả tin nhắn từ người kia là đã đọc
  WidgetsBinding.instance.addPostFrameCallback((_) {
    markMessagesAsRead();
  });
}

void markMessagesAsRead() async {
  final currentUser = FirebaseAuth.instance.currentUser!;
  
  // Lấy tất cả tin nhắn từ người kia gửi cho mình, mà mình chưa đọc
  final query = await FirebaseFirestore.instance
      .collection('messages')
      .where('participants', arrayContains: currentUser.uid)
      .where('senderId', isEqualTo: widget.receiverId)
      .get();

  for (var doc in query.docs) {
    final readBy = List<String>.from(doc.data()['readBy'] ?? []);
    if (!readBy.contains(currentUser.uid)) {
      await doc.reference.update({
        'readBy': FieldValue.arrayUnion([currentUser.uid])
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat với ${widget.receiverName}"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('messages')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs
                    .where((doc) {
                      final data = doc.data();
                      final sender = data['senderId'];
                      final receiver = data['receiverId'];
                      return (sender == currentUser.uid &&
                              receiver == widget.receiverId) ||
                          (sender == widget.receiverId &&
                              receiver == currentUser.uid);
                    })
                    .toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMe = data['senderId'] == currentUser.uid;
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                    final formattedTime =
                        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

                    return Container(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['senderName'] ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['text'] ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
