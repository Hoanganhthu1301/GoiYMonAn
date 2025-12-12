import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../food/food_detail_screen.dart';
// tránh ambiguous import: chỉ import đúng symbol cần dùng
import '../profile/profile_screen.dart' show ProfileScreen;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService();
  final _auth = FirebaseAuth.instance;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final snap = await _svc.fetchOnce(limit: 20);
      if (mounted) {
        setState(() {
          _items.addAll(snap.docs);
          if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
          _hasMore = snap.docs.length == 20;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _svc.fetchOnce(limit: 20, startAfter: _lastDoc);
      if (mounted) {
        setState(() {
          _items.addAll(snap.docs);
          if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
          _hasMore = snap.docs.length == 20;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _timeAgo(Timestamp? ts) {
    final dt = ts?.toDate();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final me = _auth.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để xem thông báo')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: _items.isEmpty
                ? null
                : () async {
                    // lấy ScaffoldMessenger trước khi await để tránh use_build_context_synchronously
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    await _svc.markAllAsRead();
                    if (!mounted) return;
                    await _loadInitial();

                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Đã đánh dấu tất cả đã đọc'),
                      ),
                    );
                  },
            child: const Text('Đọc hết', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : NotificationListener<ScrollNotification>(
                onNotification: (notif) {
                  if (notif.metrics.pixels >=
                      notif.metrics.maxScrollExtent - 200) {
                    _loadMore();
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final doc = _items[index];
                    final data = doc.data();
                    final type = (data['type'] ?? '').toString();
                    final actorName = (data['actorName'] ?? 'Người dùng')
                        .toString();
                    final actorPhotoURL = (data['actorPhotoURL'] ?? '')
                        .toString();
                    final actorId = (data['actorId'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final read = (data['read'] ?? false) == true;

                    String title = (data['title'] ?? '').toString();
                    VoidCallback? onTap;

                    if (type == 'follow') {
                      if (title.isEmpty) {
                        title = '$actorName đã theo dõi bạn';
                      }
                      onTap = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: actorId),
                          ),
                        );
                      };
                    } else if (type == 'like') {
                      if (title.isEmpty) {
                        title = '$actorName đã thích bài viết của bạn';
                      }
                      final foodId = (data['foodId'] ?? '').toString();
                      onTap = foodId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FoodDetailScreen(foodId: foodId),
                                ),
                              );
                            };
                    } else {
                      if (title.isEmpty) {
                        title = 'Thông báo mới';
                      }
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: actorPhotoURL.isNotEmpty
                            ? NetworkImage(actorPhotoURL)
                            : null,
                        child: actorPhotoURL.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(title),
                      subtitle: read
                          ? null
                          : const Text(
                              'Mới',
                              style: TextStyle(color: Colors.red),
                            ),
                      trailing: Text(
                        _timeAgo(createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        if (onTap != null) {
                          onTap();
                        }
                        await _svc.markAsRead(doc.id);
                        if (!mounted) return;
                        setState(() {}); // refresh để ẩn "Mới"
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}
