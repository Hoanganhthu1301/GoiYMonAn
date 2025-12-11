import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/gemini_service.dart';

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();

  final List<_Msg> _messages = [];
  bool _isSending = false;
  // Keys for SharedPreferences
  static const _kCurrentKey = 'chat_ai_current';
  static const _kHistoryKey = 'chat_ai_history';
  // How long to keep a conversation as resumable
  static const _resumeWindow = Duration(minutes: 5);
  List<Map<String, dynamic>> _history = [];
  bool _showHistory = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // Save current conversation when disposing
    _saveCurrentConversation();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversationState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save when app is backgrounded
    if (state == AppLifecycleState.paused) {
      _saveCurrentConversation();
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _controller.clear();
      _isSending = true;
    });

    await _scrollToBottom();

    // Heuristic: if user only says a short greeting, reply shortly and DO NOT call Gemini.
    if (_isGreetingOnly(text)) {
      final canned = 'Chào bạn!';
      setState(() {
        _messages.add(_Msg(text: canned, isUser: false));
        _isSending = false;
      });
      await _scrollToBottom();
      _saveCurrentConversation();
      return;
    }

    // If the input looks like a question or is long, call Gemini. Otherwise, send a short acknowledgement.
    if (!_isQuestionLike(text) && _wordCount(text) <= 6) {
      final shortAck = 'Mình đã nhận — nếu bạn cần trả lời chi tiết, hãy hỏi rõ hơn nhé.';
      setState(() {
        _messages.add(_Msg(text: shortAck, isUser: false));
        _isSending = false;
      });
      await _scrollToBottom();
      _saveCurrentConversation();
      return;
    }

    /// gọi Gemini chỉ khi thực sự là câu hỏi hoặc nội dung đủ dài
    final reply = await _geminiService.askNutrition(text);

    setState(() {
      _messages.add(_Msg(text: reply, isUser: false));
      _isSending = false;
    });

    await _scrollToBottom();
    // save after receiving reply
    _saveCurrentConversation();
  }

  bool _isGreetingOnly(String text) {
    final t = text.toLowerCase();
    final greetings = ['hi', 'hello', 'chào', 'chào bạn', 'hey', 'xin chào'];
    // if the text is exactly a known greeting or very short and starts with greeting
    for (var g in greetings) {
      if (t == g) return true;
      if (t.startsWith('$g ') && _wordCount(t) <= 3) return true;
    }
    return false;
  }

  bool _isQuestionLike(String text) {
    final t = text.trim();
    if (t.endsWith('?')) return true;
    final qwords = ['gì', 'sao', 'như thế nào', 'bao nhiêu', 'có', 'không', 'làm sao', 'nên', 'thế nào', 'là gì'];
    final lower = t.toLowerCase();
    for (var w in qwords) {
      if (lower.contains(' $w') || lower.startsWith('$w ')) return true;
    }
    return false;
  }

  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  // ------------------ Persistence helpers ------------------
  Future<void> _loadConversationState() async {
    final prefs = await SharedPreferences.getInstance();
    // load history
    final histRaw = prefs.getStringList(_kHistoryKey) ?? [];
    _history = histRaw.map((s) => (s.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(s)))).whereType<Map<String,dynamic>>().toList();

    final cur = prefs.getString(_kCurrentKey);
    if (cur == null) return;

    try {
      final Map<String, dynamic> data = jsonDecode(cur);
      final ts = data['timestamp'] as int? ?? 0;
      final msgs = (data['messages'] as List<dynamic>?) ?? [];
      final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      final now = DateTime.now();

      if (now.difference(savedAt) <= _resumeWindow) {
        // restore
        setState(() {
          _messages.clear();
          for (var m in msgs) {
            _messages.add(_Msg(text: m['text'] ?? '', isUser: m['isUser'] == true));
          }
        });
        // scroll after build
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        // archive old conversation into history
        await _addToHistory(data);
        await prefs.remove(_kCurrentKey);
      }
    } catch (e) {
      // ignore bad data
      print('⚠️ Failed to load chat current: $e');
    }
  }

  Future<void> _saveCurrentConversation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_messages.isEmpty) {
        await prefs.remove(_kCurrentKey);
        return;
      }

      final payload = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messages': _messages.map((m) => {'text': m.text, 'isUser': m.isUser}).toList(),
      };

      await prefs.setString(_kCurrentKey, jsonEncode(payload));
    } catch (e) {
      print('⚠️ Failed to save chat current: $e');
    }
  }

  Future<void> _addToHistory(Map<String, dynamic> convo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kHistoryKey) ?? [];
      list.insert(0, jsonEncode(convo)); // newest first
      // keep max 20
      final trimmed = list.take(20).toList();
      await prefs.setStringList(_kHistoryKey, trimmed);
      _history = trimmed.map((s) => Map<String, dynamic>.from(jsonDecode(s))).toList();
    } catch (e) {
      print('⚠️ Failed to add to chat history: $e');
    }
  }

  Future<void> _loadHistoryFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kHistoryKey) ?? [];
    _history = list.map((s) => Map<String, dynamic>.from(jsonDecode(s))).toList();
  }

  Future<void> _startNewConversation() async {
    // archive current if exists
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getString(_kCurrentKey);
    if (cur != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cur);
        await _addToHistory(data);
      } catch (_) {}
      await prefs.remove(_kCurrentKey);
    }
    setState(() {
      _messages.clear();
    });
  }

  Future<void> _openHistoryPicker() async {
    // Load history and toggle inline panel
    await _loadHistoryFromPrefs();
    setState(() {
      _showHistory = !_showHistory;
    });
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Hỏi AI về món ăn, calo, chế độ ăn…',
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat AI – Gemini'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử',
            icon: const Icon(Icons.history),
            onPressed: _openHistoryPicker,
          ),
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Bắt đầu cuộc trò chuyện mới?'),
                  content: const Text('Cuộc trò chuyện hiện tại sẽ được lưu vào lịch sử.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Hủy')),
                    TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('OK')),
                  ],
                ),
              );
              if (ok == true) await _startNewConversation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Inline history panel (shows when _showHistory is true)
          if (_showHistory)
            Container(
              height: 200,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Lịch sử cuộc trò chuyện', style: TextStyle(fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showHistory = false),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _history.isEmpty
                        ? const Center(child: Text('Chưa có lịch sử cuộc trò chuyện.'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _history.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _history[index];
                              final ts = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int);
                              final msgs = (item['messages'] as List<dynamic>? ?? []);
                              final preview = (msgs.isNotEmpty ? (msgs.last['text'] ?? '') : '').toString();
                              return ListTile(
                                title: Text('Cuộc trò chuyện ${ts.toLocal()}'),
                                subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () async {
                                  // load this conversation as current
                                  setState(() {
                                    _messages.clear();
                                    for (var m in msgs) {
                                      _messages.add(_Msg(text: m['text'] ?? '', isUser: m['isUser'] == true));
                                    }
                                    _showHistory = false;
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString(_kCurrentKey, jsonEncode(item));
                                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildBubble(_messages[index]),
            ),
          ),
          const Divider(height: 1),
          _buildInput(),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg({required this.text, required this.isUser});
}
