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
import 'package:provider/provider.dart';
import '../../main.dart'; // hoặc file nào chứa ThemeNotifier

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

  // Màu chủ đạo xanh lá, tone hiện đại (giữ nguyên để không phá cấu trúc cũ)
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color chipGreen = Color(0xFFA5D6A7);
  static const Color dangerRed = Color(0xFFE57373);

  bool _isCurrentUser = false;

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
    final me = FirebaseAuth.instance.currentUser;
    _isCurrentUser = me?.uid == widget.userId;

    // Nếu là mình: 2 tab (Tổng quan, Bài viết); người khác: chỉ tab Bài viết
    _tabController = TabController(length: _isCurrentUser ? 2 : 1, vsync: this);

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
          TextButton(
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
        const SnackBar(content: Text('Đã xóa món ăn')),
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
    // theme-aware colors with explicit dark-mode handling
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Choose palette: use theme where possible, fallback to tuned dark colors
    final background = theme.colorScheme.background;
    final cardBg = isDark ? const Color(0xFF0F1720) : theme.cardColor;
    final borderColor = isDark ? Colors.grey.shade800 : theme.dividerColor;
    final primaryText = isDark
        ? Colors.white70
        : theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final secondaryText = isDark
        ? Colors.white60
        : theme.textTheme.bodyMedium?.color ?? Colors.black54;

    final primaryGreenTheme = theme.colorScheme.primary;
    final chipBgDark = const Color(0x1A81C784); // subtle dark chip tint (hex with alpha)
    final chipGreenTheme = isDark ? chipBgDark : theme.colorScheme.primary.withOpacity(0.15);
    final dangerRedTheme = theme.colorScheme.error;
    final iconColor = isDark ? Colors.white70 : theme.iconTheme.color ?? primaryText;
    final placeholderBg = isDark ? Colors.grey.shade900 : theme.dividerColor.withOpacity(0.08);

    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: background,
      drawer: _isCurrentUser ? _buildDrawer() : null,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: iconColor),
        title: Text(
          "Trang cá nhân",
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isCurrentUser)
            IconButton(
              tooltip: 'Thêm món ăn',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddFoodPage()),
                );
                if (mounted) {
                  await _loadPosts();
                  await _loadStats();
                }
              },
              icon: Icon(Icons.add_circle_outline, color: iconColor),
            ),
          // IconButton(
          //   tooltip: 'Đăng xuất',
          //   onPressed: _logout,
          //   icon: Icon(Icons.logout, color: iconColor),
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: primaryGreenTheme,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_loadingUser)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_userData == null)
              Padding(
                padding: const EdgeInsets.all(24),
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
                _isCurrentUser,
                cardBg,
                borderColor,
                primaryText,
                secondaryText,
              ),

            const SizedBox(height: 8),

            // ---------- TAB BAR ----------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryGreenTheme,
                  borderRadius: BorderRadius.circular(24),
                ),
                labelColor: isDark ? Colors.black : Colors.white,
                unselectedLabelColor: primaryText,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                tabs: _isCurrentUser
                    ? const [
                        Tab(
                          icon: Icon(Icons.insights),
                          text: 'Tổng quan',
                        ),
                        Tab(
                          icon: Icon(Icons.grid_on),
                          text: 'Bài viết',
                        ),
                      ]
                    : const [
                        Tab(
                          icon: Icon(Icons.grid_on),
                          text: 'Bài viết',
                        ),
                      ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: size.height * 0.50, // khoảng 75% chiều cao màn hình
              child: TabBarView(
                controller: _tabController,
                children: _isCurrentUser
                    ? [
                        _buildOverviewTab(
                          cardBg,
                          borderColor,
                          primaryText,
                          secondaryText,
                        ),
                        _buildPostsTab(secondaryText),
                      ]
                    : [
                        _buildPostsTab(secondaryText),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _bmiStatusText(num bmi) {
    if (bmi < 18.5) return 'Thiếu cân';
    if (bmi < 23) return 'Bình thường'; // chuẩn châu Á
    if (bmi < 27.5) return 'Thừa cân';
    return 'Béo phì';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryGreenTheme = theme.colorScheme.primary;
    final avatarBg = isDark ? Colors.grey.shade800 : theme.dividerColor;

    // Avatar
    final photoURL = (userData['photoURL']?.toString().trim().isNotEmpty ?? false)
        ? userData['photoURL'].toString()
        : defaultAvatarUrl;

    // Tên hiển thị với fallback
    final fsName = (userData['displayName'] as String?)?.trim();
    String displayName;
    if (fsName != null && fsName.isNotEmpty) {
      displayName = fsName;
    } else {
      final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      if (authName != null && authName.isNotEmpty) {
        displayName = authName;
      } else {
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null && email.contains('@')) {
          displayName = email.split('@')[0];
        } else {
          displayName = 'Tên người dùng';
        }
      }
    }

    // Username
    final fsUsername = (userData['username'] as String?)?.trim();
    String username;
    if (fsUsername != null && fsUsername.isNotEmpty) {
      username = '@$fsUsername';
    } else {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null && email.contains('@')) {
        username = '@' + email.split('@')[0];
      } else {
        username = '';
      }
    }

    // Bio
    final bio = (userData['bio']?.toString().trim().isNotEmpty ?? false)
        ? userData['bio'].toString()
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name + actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage(photoURL),
                backgroundColor: avatarBg,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (username.isNotEmpty)
                      Text(
                        username,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bio,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statColumn(
                  _loadingStats ? null : _followersCount,
                  'Người theo dõi',
                  primaryText,
                  secondaryText),
              _statColumn(
                  _loadingStats ? null : _followingCount,
                  'Đang theo dõi',
                  primaryText,
                  secondaryText),
              _statColumn(
                  _loadingStats ? null : _postsCount,
                  'Bài viết',
                  primaryText,
                  secondaryText),
            ],
          ),

          const SizedBox(height: 14),

          // Buttons
          if (!isCurrentUser)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
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
                      backgroundColor: _isFollowing
                          ? Theme.of(context).disabledColor
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: _isFollowing
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(_isFollowing ? 'Đang theo dõi' : 'Theo dõi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (currentUserId == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            receiverId: widget.userId,
                            receiverName: displayName,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text("Nhắn tin"),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(userId: widget.userId),
                    ),
                  );
                  if (mounted) await _loadUser();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Chỉnh sửa hồ sơ'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    Color cardBg,
    Color borderColor,
    Color primaryText,
    Color secondaryText,
  ) {
    if (_userData == null) return const Center(child: CircularProgressIndicator());

    final weight = (_userData!['weight'] as num?)?.toDouble();
    final height = (_userData!['height'] as num?)?.toDouble();
    final age = (_userData!['age'] as num?)?.toInt();
    final gender = (_userData!['gender'] as String?);
    final bmi = (_userData!['bmi'] as num?)?.toDouble();
    final targetWeight = (_userData!['targetWeight'] as num?)?.toDouble();
    final dietType = (_userData!['dietType'] as String?);
    final goal = (_userData!['goal'] as String?);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipBg = isDark ? Colors.white10 : theme.colorScheme.primary.withOpacity(0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông tin cơ bản
            _infoCard(
              title: 'Thông tin cơ bản',
              children: [
                _infoTile(icon: Icons.monitor_weight, label: 'Cân nặng', value: weight != null ? '${weight.toStringAsFixed(1)} kg' : 'Chưa cập nhật'),
                _infoTile(icon: Icons.height, label: 'Chiều cao', value: height != null ? '${height.toStringAsFixed(1)} cm' : 'Chưa cập nhật'),
                _infoTile(icon: Icons.cake, label: 'Tuổi', value: age != null ? '$age tuổi' : 'Chưa cập nhật'),
                _infoTile(icon: Icons.person, label: 'Giới tính', value: gender ?? 'Chưa cập nhật'),
              ],
            ),

            const SizedBox(height: 12),

            // BMI & mục tiêu cân nặng
            _infoCard(
              title: 'Chỉ số cơ thể',
              children: [
                if (bmi != null) _infoTile(icon: Icons.monitor_weight, label: 'BMI', value: '${bmi.toStringAsFixed(1)} – ${_bmiStatusText(bmi)}'),
                if (targetWeight != null) _infoTile(icon: Icons.flag, label: 'Cân nặng mục tiêu', value: '${targetWeight.toStringAsFixed(1)} kg'),
              ],
            ),

            const SizedBox(height: 12),

            // Mục tiêu & chế độ ăn
            _infoCard(
              title: 'Mục tiêu & chế độ ăn',
              children: [
                _infoTile(icon: Icons.flag, label: 'Mục tiêu', value: goal ?? 'Chưa cập nhật'),
                _infoTile(icon: Icons.restaurant_menu, label: 'Chế độ ăn', value: dietType ?? 'Chưa cập nhật'),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Card chung cho Overview
  Widget _infoCard({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF0B1220) : theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white70 : Colors.black87);

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  // Tile gọn cho từng thông tin
  Widget _infoTile({required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    final iconC = theme.colorScheme.primary;
    final labelColor = theme.textTheme.bodyMedium?.color ?? (theme.brightness == Brightness.dark ? Colors.white60 : Colors.black54);
    final valueColor = theme.textTheme.bodyLarge?.color ?? (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87);

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconC),
              const SizedBox(width: 6),
              Flexible(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor))),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
        ],
      ),
    );
  }

  // ================== INFO CHIP ==================
  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final chipBgColor = theme.brightness == Brightness.dark ? Colors.white10 : theme.colorScheme.primary.withOpacity(0.08);
    final iconC = theme.colorScheme.primary;
    final labelColor = theme.textTheme.bodyMedium?.color ?? Colors.black54;
    final valueColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipBgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconC),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: labelColor)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== TAB BÀI VIẾT (MÓN ĂN) ==================
  Widget _buildPostsTab(Color secondaryText) {
    final theme = Theme.of(context);
    final placeholderBg = theme.brightness == Brightness.dark ? Colors.grey.shade900 : theme.dividerColor.withOpacity(0.08);

    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'Chưa có bài viết nào.',
          style: TextStyle(color: secondaryText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final post = _posts[index];
          final data = post.data() as Map<String, dynamic>;
          final imageUrl = (data['image_url'] ?? '') as String;
          final foodId = post.id;
          final isOwner = currentUserId == data['authorId'];

          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodDetailScreen(foodId: foodId),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              Container(color: placeholderBg),
                        )
                      : Container(color: placeholderBg),
                  if (isOwner)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _buildPostMenu(foodId, data),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostMenu(String foodId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.onBackground.withOpacity(0.45);
    final popupBg = theme.cardColor;
    final popupTextColor = theme.textTheme.bodyLarge?.color ?? (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87);
    final deleteColor = theme.colorScheme.error;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: overlayColor,
        child: PopupMenuButton<String>(
          color: popupBg,
          icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.onPrimary),
          elevation: 4,
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditFoodPage(
                    foodId: foodId,
                    data: data,
                  ),
                ),
              );
              if (mounted) await _loadPosts();
            } else if (value == 'delete') {
              await _deleteFood(foodId);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Text('Sửa', style: TextStyle(color: popupTextColor)),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Xóa',
                style: TextStyle(color: deleteColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== STAT COLUMN ==================
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
        Text(label, style: TextStyle(color: secondaryText, fontSize: 12)),
      ],
    );
  }

  // ================== DRAWER (DÀNH CHO MÌNH) ==================
  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final iconColor = theme.iconTheme.color ?? theme.textTheme.bodyLarge?.color ?? (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87);
    final card = theme.cardColor;
    final error = theme.colorScheme.error;
    final accent = theme.colorScheme.secondary;

    return Drawer(
      backgroundColor: card,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Trang cá nhân',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'Người dùng',
                  style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.light_mode, color: accent),
            title: Text('Chế độ sáng/tối', style: TextStyle(color: iconColor)),
            onTap: () {
              context.read<ThemeNotifier>().toggleTheme();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.info, color: iconColor),
            title: Text('Thông tin ứng dụng', style: TextStyle(color: iconColor)),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: error),
            title: Text('Đăng xuất', style: TextStyle(color: iconColor)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            const Icon(Icons.restaurant_menu, size: 40),
            const SizedBox(width: 10),
            const Text('SupLo App'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ứng dụng quản lý món ăn và dinh dưỡng.\n'
              'Giúp theo dõi lượng calo, quản lý thực đơn và khám phá các món ăn mới.',
            ),
            const SizedBox(height: 12),
            Text(
              'Phiên bản: 1.0.0',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              '© 2025 SupLo App. All rights reserved.',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? Colors.black54),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                // mở email hoặc website
              },
              child: Text(
                'Liên hệ: suplo@foodapp.com',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
