import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/message_service.dart';
import 'package:doan/widgets/message_bubble.dart'; // import MessageBubble

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
  final _msgSvc = MessageService();

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
      'readBy': [user.uid],
    });

    _controller.clear();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _msgSvc.markAsRead(widget.receiverId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser!;
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
        backgroundColor: primary,
        elevation: 1,
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMe = data['senderId'] == currentUser.uid;
                    final timestamp =
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();

                    return MessageBubble(
                      message: data['text'] ?? '',
                      isMe: isMe,
                      userId: data['senderId'] ?? '',
                      username: data['senderName'] ?? 'Người dùng',
                      timestamp: timestamp,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primary,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
