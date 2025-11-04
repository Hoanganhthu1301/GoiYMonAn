import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../food/food_detail_screen.dart';
import '../account/login_screen.dart';
import 'edit_profile_screen.dart';
import '../food/edit_food_page.dart';
import '../../services/follow_service.dart';
import '../../services/fcm_token_service.dart';
import '../chat/chat_screen.dart';
import '../food/add_food_page.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
  final _followSvc = FollowService();

  bool _loadingStats = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  bool _loadingPosts = true;
  List<QueryDocumentSnapshot> _posts = [];

  bool _loadingUser = true;
  Map<String, dynamic>? _userData;

  late TabController _tabController;

  static const defaultAvatarUrl =
      'https://static.vecteezy.com/system/resources/previews/009/734/564/original/default-avatar-profile-icon-of-social-media-user-vector.jpg';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadUser(), _loadStats(), _loadPosts()]);
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      _userData = snap.data();
    } catch (e) {
      debugPrint('Load user error: $e');
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final following = await _followSvc.isFollowingOnce(widget.userId);
      final followersCount = await _followSvc.followersCountOnce(widget.userId);
      final followingCount = await _followSvc.followingCountOnce(widget.userId);

      int postsCount = _posts.isNotEmpty ? _posts.length : 0;
      try {
        final agg = await FirebaseFirestore.instance
            .collection('foods')
            .where('authorId', isEqualTo: widget.userId)
            .count()
            .get();
        postsCount = (agg.count ?? postsCount);
      } catch (_) {
        if (postsCount == 0) {
          final qs = await FirebaseFirestore.instance
              .collection('foods')
              .where('authorId', isEqualTo: widget.userId)
              .get();
          postsCount = qs.docs.length;
        }
      }

      _isFollowing = following;
      _followersCount = followersCount;
      _followingCount = followingCount;
      _postsCount = postsCount;
    } catch (e) {
      debugPrint('Load stats error: $e');
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final qs = await FirebaseFirestore.instance
          .collection('foods')
          .where('authorId', isEqualTo: widget.userId)
          .orderBy('created_at', descending: true)
          .get();
      _posts = qs.docs;
    } catch (e) {
      debugPrint('Load posts error: $e');
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _deleteFood(String foodId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món ăn'),
        content: const Text('Bạn có chắc chắn muốn xóa món ăn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('foods').doc(foodId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã xóa món ăn')),
      );
      await _loadPosts();
      await _loadStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
    }
  }

  Future<void> _logout() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me != null) {
      try {
        await FcmTokenService().unlinkAndDeleteToken();
      } catch (_) {}
    }
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã đăng xuất')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (c) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = currentUserId == widget.userId;

    const background = Colors.white;
    const cardBg = Color(0xFFF6F6F6);
    const borderColor = Color(0xFFE6E6E6);
    const primaryText = Colors.black87;
    const secondaryText = Colors.black54;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Trang cá nhân",
          style: TextStyle(color: primaryText),
        ),
        actions: [
        if (isCurrentUser) ...[
          IconButton(
            tooltip: 'Thêm món ăn',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFoodPage()),
              );
              // Sau khi thêm món ăn xong, load lại danh sách bài viết
              if (mounted) {
                await _loadPosts();
                await _loadStats();
              }
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.black87),
          ),
        ],
      ],
    ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: Colors.blue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_loadingUser)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_userData == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Không tìm thấy người dùng.',
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              )
            else
              _buildProfileHeader(
                context,
                _userData!,
                isCurrentUser,
                cardBg,
                borderColor,
                primaryText,
                secondaryText,
              ),
            Divider(color: borderColor, height: 1),
            Container(
              color: background,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blue,
                    labelColor: primaryText,
                    unselectedLabelColor: secondaryText,
                    tabs: const [Tab(icon: Icon(Icons.grid_on, size: 20))],
                  ),
                  SizedBox(
                    height: 460,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _loadingPosts
                            ? const Center(child: CircularProgressIndicator())
                            : _posts.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Chưa có bài viết nào.',
                                      style: TextStyle(color: secondaryText),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(2),
                                    itemCount: _posts.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 2,
                                      mainAxisSpacing: 2,
                                    ),
                                    itemBuilder: (context, index) {
                                      final post = _posts[index];
                                      final data =
                                          post.data() as Map<String, dynamic>;
                                      final imageUrl =
                                          (data['image_url'] ?? '') as String;
                                      final foodId = post.id;
                                      final isOwner =
                                          currentUserId == data['authorId'];

                                      return GestureDetector(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FoodDetailScreen(
                                                  foodId: foodId),
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            imageUrl.isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  )
                                                : Container(
                                                    color: Colors.grey.shade200,
                                                  ),
                                            if (isOwner)
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child:
                                                    PopupMenuButton<String>(
                                                  color: Colors.white,
                                                  elevation: 2,
                                                  onSelected: (value) async {
                                                    if (value == 'edit') {
                                                      await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              EditFoodPage(
                                                            foodId: foodId,
                                                            data: data,
                                                          ),
                                                        ),
                                                      );
                                                      if (mounted) {
                                                        await _loadPosts();
                                                      }
                                                    } else if (value ==
                                                        'delete') {
                                                      await _deleteFood(
                                                          foodId);
                                                    }
                                                  },
                                                  itemBuilder: (ctx) => const [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('✏️ Sửa'),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text(
                                                        '🗑️ Xóa',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
  BuildContext context,
  Map<String, dynamic> userData,
  bool isCurrentUser,
  Color cardBg,
  Color borderColor,
  Color primaryText,
  Color secondaryText,
) {
  final photoURL = (userData['photoURL'] ?? defaultAvatarUrl) as String;
  final displayName = (userData['displayName'] ?? 'Tên người dùng') as String;
  final username =
      userData['username'] != null ? '@${userData['username']}' : '';
  final bio = (userData['bio'] ?? '').toString().trim();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  return Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1️⃣ Avatar và thống kê bài viết / followers / following
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(photoURL),
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statColumn(
                      _loadingStats ? null : _postsCount,
                      'bài viết',
                      primaryText,
                      secondaryText),
                  _statColumn(
                      _loadingStats ? null : _followersCount,
                      'người theo dõi',
                      primaryText,
                      secondaryText),
                  _statColumn(
                      _loadingStats ? null : _followingCount,
                      'đang theo dõi',
                      primaryText,
                      secondaryText),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2️⃣ Tên + username + emoji
        Text(
          displayName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (username.isNotEmpty)
              Text(username,
                  style: TextStyle(color: secondaryText, fontSize: 14)),
            const SizedBox(width: 8),
            if (userData['emoji'] != null)
              Text(userData['emoji'], style: const TextStyle(fontSize: 14)),
          ],
        ),

        const SizedBox(height: 8),

        // 3️⃣ Bio
        if (bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              bio,
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

        // 4️⃣ Nút hành động nằm **dưới tên, username, bio**
        if (!isCurrentUser)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(_isFollowing ? Icons.check : Icons.person_add),
                  label: Text(_isFollowing ? 'Đang theo dõi' : 'Theo dõi'),
                  onPressed: currentUserId == null
                      ? null
                      : () async {
                          try {
                            if (_isFollowing) {
                              await _followSvc.unfollow(widget.userId);
                            } else {
                              await _followSvc.follow(widget.userId);
                            }
                            await _loadStats();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isFollowing ? Colors.grey.shade300 : Colors.orange,
                    foregroundColor:
                        _isFollowing ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Nhắn tin"),
                  onPressed: () {
                    if (currentUserId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          receiverId: widget.userId,
                          receiverName:
                              userData['displayName'] ?? 'Người dùng',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),

        if (isCurrentUser)
          Row(
            children: [
              // Current user: 2 nút ngang → Chỉnh sửa / Chia sẻ
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditProfileScreen(userId: widget.userId),
                      ),
                    );
                    if (mounted) await _loadUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryText,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Chỉnh sửa'),
                ),
              ),
            ],
          ),

        const SizedBox(height: 12),
      ],
    ),
  );
}

  Widget _statColumn(
    int? value,
    String label,
    Color primaryText,
    Color secondaryText,
  ) {
    return Column(
      children: [
        Text(
          value != null ? '$value' : '-',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: secondaryText)),
      ],
    );
  }
}
