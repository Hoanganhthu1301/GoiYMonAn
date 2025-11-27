import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentSection extends StatefulWidget {
  final String foodId;
  final int pageSize;

  const CommentSection({super.key, required this.foodId, this.pageSize = 10});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _listController = ScrollController();

  // Store comments as simple Maps to avoid snapshot type conflicts
  List<Map<String, dynamic>> docs = [];
  bool loadingInitial = false;
  bool loadingMore = false;
  bool hasMore = true;

  // Sending flag tách riêng
  bool _isSending = false;

  // Pagination
  DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  // Realtime
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? realtimeSub;
  bool _realtimePrimed = false; // bỏ qua emit đầu tiên để tránh trùng initial
  String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
    _bootstrap();

    // Set Vietnamese locale cho timeago (optional)
    try {
      timeago.setLocaleMessages('vi', timeago.ViMessages());
    } catch (_) {}
    _listController.addListener(_scrollListener);
  }

  Future<void> _bootstrap() async {
    await _loadInitial();
    _startRealtimeListener();
  }

  @override
  void didUpdateWidget(covariant CommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodId != widget.foodId) {
      _resetAndReload();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _listController.removeListener(_scrollListener);
    _listController.dispose();
    realtimeSub?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (!_listController.hasClients) return;
    if (_listController.position.pixels >=
            _listController.position.maxScrollExtent - 100 &&
        !loadingMore &&
        hasMore) {
      _loadMore();
    }
  }

  Future<void> _resetAndReload() async {
    await realtimeSub?.cancel();
    realtimeSub = null;
    _realtimePrimed = false;

    setState(() {
      docs = [];
      lastDoc = null;
      hasMore = true;
    });
    await _loadInitial();
    _startRealtimeListener();
  }

  List<Map<String, dynamic>> _docsFromQuerySnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs.map((d) {
      final data = d.data();
      final map = <String, dynamic>{'id': d.id};
      map.addAll(data);
      return map;
    }).toList();
  }

  Future<void> _loadInitial() async {
    if (loadingInitial) return;
    setState(() => loadingInitial = true);
    try {
      final q = _db
          .collection('comments')
          .where('foodId', isEqualTo: widget.foodId)
          .orderBy('createdAt', descending: true)
          .limit(widget.pageSize);

      final snap = await q.get();
      final loaded = _docsFromQuerySnapshot(snap);

      setState(() {
        docs = loaded;
        lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        hasMore = snap.docs.length == widget.pageSize;
      });
    } catch (e, st) {
      debugPrint('loadInitial comments error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi tải bình luận: $e')));
      }
    } finally {
      if (mounted) setState(() => loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore || lastDoc == null) return;
    setState(() => loadingMore = true);
    try {
      final q = _db
          .collection('comments')
          .where('foodId', isEqualTo: widget.foodId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc!)
          .limit(widget.pageSize);

      final snap = await q.get();
      final newMaps = _docsFromQuerySnapshot(snap);

      // Dedupe theo id
      final existingIds = docs.map((e) => e['id'] as String).toSet();
      final deduped = newMaps.where((m) => !existingIds.contains(m['id']));

      setState(() {
        docs.addAll(deduped);
        lastDoc = snap.docs.isNotEmpty ? snap.docs.last : lastDoc;
        hasMore = newMaps.length == widget.pageSize;
      });
    } catch (e, st) {
      debugPrint('loadMore comments error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải thêm bình luận: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để bình luận')),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final authorName = user.displayName ?? user.email ?? 'Người dùng';

      // Tạo id trước để chèn optimistic-item có cùng id
      final ref = _db.collection('comments').doc();

      // Optimistic UI: chèn item tạm thời để thấy ngay
      final pendingItem = {
        'id': ref.id,
        'foodId': widget.foodId,
        'text': text,
        'authorId': user.uid,
        'authorName': authorName,
        'createdAt': Timestamp.now(),
        '_pending': true,
      };
      setState(() {
        docs.insert(0, pendingItem);
      });

      // Ghi thật lên Firestore (serverTimestamp)
      await ref.set({
        'foodId': widget.foodId,
        'text': text,
        'authorId': user.uid,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _controller.clear();

      // Scroll lên đầu
      if (_listController.hasClients) {
        _listController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e, st) {
      debugPrint('postComment error: $e\n$st');
      if (mounted) {
        // Nếu lỗi, loại bỏ optimistic item (nếu còn ở đầu danh sách)
        docs.removeWhere((d) => d['_pending'] == true);
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi bình luận thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startRealtimeListener() {
    // Hủy listener cũ nếu có
    realtimeSub?.cancel();
    _realtimePrimed = false;

    // Nghe top các bình luận theo thời gian giảm dần
    final q = _db
        .collection('comments')
        .where('foodId', isEqualTo: widget.foodId)
        .orderBy('createdAt', descending: true)
        .limit(widget.pageSize + 5); // buffer nhỏ

    realtimeSub = q.snapshots().listen(
      (snap) {
        // Bỏ qua emit đầu (nó chứa lại các doc đã có từ initial load)
        if (!_realtimePrimed) {
          _realtimePrimed = true;
          return;
        }

        // Xử lý các thay đổi
        for (final change in snap.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;
          final id = change.doc.id;

          if (change.type == DocumentChangeType.added) {
            final idx = docs.indexWhere((d) => d['id'] == id);
            if (idx >= 0) {
              // Thay thế optimistic item bằng dữ liệu thật (cập nhật serverTimestamp)
              setState(() {
                docs[idx] = {'id': id, ...data};
              });
            } else {
              setState(() {
                docs.insert(0, {'id': id, ...data});
              });
            }
          } else if (change.type == DocumentChangeType.modified) {
            final idx = docs.indexWhere((d) => d['id'] == id);
            if (idx >= 0) {
              setState(() {
                docs[idx] = {'id': id, ...data};
              });
            }
          } else if (change.type == DocumentChangeType.removed) {
            final idx = docs.indexWhere((d) => d['id'] == id);
            if (idx >= 0) {
              setState(() {
                docs.removeAt(idx);
              });
            }
          }
        }
      },
      onError: (e, st) {
        debugPrint('Realtime listener error: $e\n$st');
      },
    );
  }

  Future<void> _deleteComment(String docId, String authorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != authorId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn không có quyền xóa bình luận này')),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _db.collection('comments').doc(docId).delete();
      if (mounted) {
        setState(() => docs.removeWhere((d) => d['id'] == docId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận')));
      }
    } catch (e, st) {
      debugPrint('deleteComment error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
      }
    }
  }

  Future<void> _refresh() async {
    await _resetAndReload();
  }

  Widget _buildCommentItemFromMap(Map<String, dynamic> doc) {
    final text = doc['text'] ?? '';
    final authorName = doc['authorName'] ?? 'Người dùng';
    final authorId = doc['authorId'] ?? '';
    final ts = doc['createdAt'];
    final id = doc['id'] ?? '';

    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is Map && ts['_seconds'] != null) {
      time = DateTime.fromMillisecondsSinceEpoch(
        (ts['_seconds'] as int) * 1000,
      );
    } else {
      time = DateTime.now();
    }

    final timeStr = timeago.format(time, locale: 'vi');
    final isOwner = authorId == uid;

    return ListTile(
      title: Text(
        authorName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(text),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                timeStr,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              if (isOwner)
                GestureDetector(
                  onTap: () => _deleteComment(id, authorId),
                  child: const Text(
                    'Xóa',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 80, maxHeight: 360),
          child: loadingInitial && docs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _listController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length + (hasMore ? 1 : 0),
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index < docs.length) {
                        return _buildCommentItemFromMap(docs[index]);
                      } else {
                        // Footer "xem thêm"
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Center(
                            child: loadingMore
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: const Text('Xem thêm bình luận'),
                                  ),
                          ),
                        );
                      }
                    },
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Viết bình luận...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _postComment,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
