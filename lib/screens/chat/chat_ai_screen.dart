import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/gemini_service.dart';

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _gemini = GeminiService();

  final List<_Msg> _messages = [];
  StreamSubscription<QuerySnapshot>? _messageSub;

  bool _isSending = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _initChat();
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final cid = await _gemini.getCurrentConversationId();
    _switchConversation(cid);
  }

  void _switchConversation(String cid) {
    _messageSub?.cancel();
    _messages.clear();
    _messageSub = _gemini.streamMessages(cid).listen((snapshot) {
      final list = snapshot.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return _Msg(
          text: data['text'] ?? '',
          isUser: data['role'] == 'user',
        );
      }).toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });

      _scrollToBottom();
    });
  }

  // ================= SEND =================

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || _user == null) return;

    _controller.clear();
    setState(() => _isSending = true);

    // Save user message
    await _gemini.saveChat(role: 'user', text: text);

    try {
      final reply = await _gemini.askNutrition(text);
      await _gemini.saveChat(role: 'ai', text: reply);
    } catch (_) {
      await _gemini.saveChat(
        role: 'ai',
        text: '⚠️ AI đang bận, bạn thử lại sau nha.',
      );
    }

    setState(() => _isSending = false);
  }

  // ================= HISTORY =================

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return StreamBuilder<QuerySnapshot>(
          stream: _gemini.streamConversations(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có lịch sử chat'),
              );
            }

            return ListView(
              children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.chat),
                  title: Text(data['title'] ?? 'Cuộc trò chuyện'),
                  subtitle: Text(data['summary'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _gemini.deleteConversation(d.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _switchConversation(d.id);
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để dùng Chat AI')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA5D6A7),
        elevation: 0,
        title: GestureDetector(
          onTap: _showHistorySheet,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chat AI',
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(width: 4),
              Icon(Icons.history, color: Colors.black54),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            tooltip: 'Chat mới',
            onPressed: () async {
               _gemini.resetCurrentConversation();
              final cid = await _gemini.startNewConversation();
              _switchConversation(cid);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i]),
            ),
          ),
          const Divider(height: 1),
          _input(),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: m.isUser
              ? const Color(0xFF64B5F6)
              : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.only(  
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isUser ? 16 : 0),
            bottomRight: Radius.circular(m.isUser ? 0 : 16),
          ),
        ),
        child: Text(
          m.text,
          style: TextStyle(
            color: m.isUser ? Colors.white : Colors.black87,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _input() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Hỏi AI về calo, món ăn, chế độ ăn...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.green),
              onPressed: _isSending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;

  _Msg({required this.text, required this.isUser});
}
