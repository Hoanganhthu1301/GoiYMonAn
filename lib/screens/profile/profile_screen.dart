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
import '../../services/calorie_service.dart';
import '../../services/intake_service.dart';
import '../articles/articles_screen.dart';

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

  // Màu chủ đạo xanh lá, tone hiện đại
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
    const background = softGreen;
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE0E0E0);
    const primaryText = Colors.black87;
    const secondaryText = Colors.black54;

    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: background,
      drawer: _isCurrentUser ? _buildDrawer() : null, // Drawer chỉ mình thấy
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        title: const Text(
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
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: primaryGreen,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                labelColor: Colors.white,
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
    if (bmi < 23) return 'Bình thường';        // chuẩn châu Á
    if (bmi < 27.5) return 'Thừa cân';
    return 'Béo phì';
  }

  // ================== HEADER PROFILE ==================
Widget _buildProfileHeader(
  BuildContext context,
  Map<String, dynamic> userData,
  bool isCurrentUser,
  Color cardBg,
  Color borderColor,
  Color primaryText,
  Color secondaryText,
) {
  // Avatar
  final photoURL = (userData['photoURL']?.toString().trim().isNotEmpty ?? false)
      ? userData['photoURL'].toString()
      : defaultAvatarUrl;

  // Tên hiển thị với fallback
   // Tên hiển thị với fallback chain:
  // 1) Firestore displayName
  // 2) FirebaseAuth.currentUser.displayName
  // 3) email username (phần trước @)
  // 4) default 'Tên người dùng'
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

  // Username: ưu tiên trường username trong Firestore, nếu không có
  // thì dùng @ + email-username (nếu có), hoặc để rỗng.
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

  // Bio với fallback
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
          color: Colors.black12.withOpacity(0.03),
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
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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
                        ? Colors.grey.shade200
                        : primaryGreen,
                    foregroundColor:
                        _isFollowing ? primaryText : Colors.white,
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
                      color: primaryGreen.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text("Nhắn tin"),
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
                foregroundColor: primaryGreen,
                side: const BorderSide(color: primaryGreen),
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
  if (_userData == null) {
    return const Center(child: Text('Đang tải...'));
  }

  final uid = widget.userId;

  // Lấy dữ liệu từ Firestore
  final double? weight =
      (_userData!['weight'] as num?)?.toDouble();        // kg
  final double? height =
      (_userData!['height'] as num?)?.toDouble();        // cm
  final int? age = (_userData!['age'] as num?)?.toInt();
  final String? gender = _userData!['gender'] as String?;
  final double? bmi = (_userData!['bmi'] as num?)?.toDouble();
  final double? targetWeight =
      (_userData!['targetWeight'] as num?)?.toDouble();
  final String? dietType = _userData!['dietType'] as String?;
  final String? goal = _userData!['goal'] as String?;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SingleChildScrollView(
      primary: false, 
    physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Thẻ thống kê calo
          // _buildCalorieCard(uid, cardBg, borderColor),
          const SizedBox(height: 16),

          // ====== THÔNG TIN CƠ BẢN ======
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Thông tin cá nhân",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoChip(
                      icon: Icons.monitor_weight,
                      label: 'Cân nặng',
                      value: weight != null ? '${weight.toStringAsFixed(1)} kg' : 'Chưa cập nhật',
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      icon: Icons.height,
                      label: 'Chiều cao',
                      value: height != null ? '${height.toStringAsFixed(1)} cm' : 'Chưa cập nhật',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip(
                      icon: Icons.cake,
                      label: 'Tuổi',
                      value: age != null ? '$age tuổi' : 'Chưa cập nhật',
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      icon: Icons.person,
                      label: 'Giới tính',
                      value: gender ?? 'Chưa cập nhật',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ====== BMI + CÂN NẶNG MỤC TIÊU ======
          if (bmi != null || targetWeight != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Chỉ số cơ thể",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (bmi != null) ...[
                    Text(
                      'BMI: ${bmi.toStringAsFixed(1)} – ${_bmiStatusText(bmi)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (targetWeight != null)
                    Text(
                      'Cân nặng mục tiêu: ${targetWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 14),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ====== MỤC TIÊU & CHẾ ĐỘ ĂN ======
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Mục tiêu & chế độ ăn",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoChip(
                      icon: Icons.flag,
                      label: 'Mục tiêu',
                      value: goal ?? 'Chưa cập nhật',
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      icon: Icons.restaurant_menu,
                      label: 'Chế độ ăn',
                      value: dietType ?? 'Chưa cập nhật',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}


  // Widget _buildCalorieCard(
  //   String uid,
  //   Color cardBg,
  //   Color borderColor,
  // ) {
  //   return StreamBuilder<int?>(
  //     stream: CalorieService.instance.dailyGoalStream(),
  //     builder: (context, goalSnap) {
  //       if (goalSnap.connectionState == ConnectionState.waiting) {
  //         return const Padding(
  //           padding: EdgeInsets.all(8),
  //           child: LinearProgressIndicator(),
  //         );
  //       }

  //       final int? dailyGoalVal = goalSnap.data;
  //       if (dailyGoalVal == null || dailyGoalVal == 0) {
  //         return Container(
  //           padding: const EdgeInsets.all(14),
  //           decoration: BoxDecoration(
  //             color: cardBg,
  //             borderRadius: BorderRadius.circular(16),
  //             border: Border.all(color: borderColor),
  //           ),
  //           child: const Text(
  //             "Bạn chưa thiết lập mục tiêu calo.\nHãy vào cài đặt để thêm mục tiêu.",
  //             style: TextStyle(fontSize: 14),
  //           ),
  //         );
  //       }

  //       final int dailyGoal = dailyGoalVal;

  //       return StreamBuilder<double>(
  //         stream: IntakeService().todayCaloriesTotalStream(uid),
  //         builder: (context, intakeSnap) {
  //           final consumed = intakeSnap.data ?? 0.0;
  //           final remaining = (dailyGoal - consumed).clamp(0, 99999);
  //           final percentage = (consumed / dailyGoal * 100).clamp(0, 100);

  //           Color barColor;
  //           if (percentage < 70) {
  //             barColor = primaryGreen;
  //           } else if (percentage < 100) {
  //             barColor = Colors.orange;
  //           } else {
  //             barColor = dangerRed;
  //           }

  //           return Container(
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               gradient: const LinearGradient(
  //                 colors: [softGreen, Colors.white],
  //                 begin: Alignment.topLeft,
  //                 end: Alignment.bottomRight,
  //               ),
  //               borderRadius: BorderRadius.circular(16),
  //               border: Border.all(color: borderColor),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "Thống kê calo hôm nay",
  //                   style: TextStyle(
  //                     fontWeight: FontWeight.w600,
  //                     fontSize: 16,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 ClipRRect(
  //                   borderRadius: BorderRadius.circular(10),
  //                   child: LinearProgressIndicator(
  //                     value: percentage / 100,
  //                     minHeight: 10,
  //                     backgroundColor: Colors.grey.shade200,
  //                     valueColor: AlwaysStoppedAnimation(barColor),
  //                   ),
  //                 ),
  //                 const SizedBox(height: 10),
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     _caloItem(
  //                       title: "Mục tiêu",
  //                       value: "$dailyGoal kcal",
  //                       align: CrossAxisAlignment.start,
  //                     ),
  //                     _caloItem(
  //                       title: "Đã ăn",
  //                       value: "${consumed.round()} kcal",
  //                       align: CrossAxisAlignment.center,
  //                     ),
  //                     _caloItem(
  //                       title: "Còn lại",
  //                       value: "${remaining.round()} kcal",
  //                       align: CrossAxisAlignment.end,
  //                       valueColor: primaryGreen,
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  // Widget _caloItem({
  //   required String title,
  //   required String value,
  //   CrossAxisAlignment align = CrossAxisAlignment.start,
  //   Color? valueColor,
  // }) {
  //   return Expanded(
  //     child: Column(
  //       crossAxisAlignment: align,
  //       children: [
  //         Text(
  //           title,
  //           style: const TextStyle(fontSize: 12, color: Colors.black54),
  //         ),
  //         const SizedBox(height: 2),
  //         Text(
  //           value,
  //           style: TextStyle(
  //             fontWeight: FontWeight.bold,
  //             color: valueColor ?? Colors.black87,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipGreen.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
                              Container(color: Colors.grey.shade200),
                        )
                      : Container(color: Colors.grey.shade200),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.black45,
        child: PopupMenuButton<String>(
          color: Colors.white,
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.white),
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
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Sửa'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
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
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: primaryGreen,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Trang cá nhân',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'Người dùng',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article, color: primaryGreen),
            title: const Text('Bài viết của tôi'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArticlesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('Người theo dõi'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_followersCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showFollowersList();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.green),
            title: const Text('Đang theo dõi'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_followingCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showFollowingList();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.grey),
            title: const Text('Thông tin ứng dụng'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showFollowersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Người theo dõi'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('follows')
                .where('followingId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Chưa có người theo dõi'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final followerId = docs[index]['followerId'];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(followerId)
                        .get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final userData =
                          snap.data!.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(userData['displayName'] ?? 'User'),
                        subtitle: Text(
                          userData['email'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showFollowingList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đang theo dõi'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('follows')
                .where('followerId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Chưa theo dõi ai'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final followingId = docs[index]['followingId'];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(followingId)
                        .get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final userData =
                          snap.data!.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(userData['displayName'] ?? 'User'),
                        subtitle: Text(
                          userData['email'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông tin ứng dụng'),
        content: const Text(
          'Ứng dụng tính calo và gợi ý thực đơn.\n\n'
          'Giúp bạn quản lý lượng calo hàng ngày '
          'và nhận gợi ý món ăn phù hợp.\n\n'
          'Phiên bản 1.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
