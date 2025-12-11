// lib/screens/home/home_screen.dart
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/notifications_button.dart';
import '../chat/all_message.dart';
import 'package:doan/screens/menu/daily_menu_screen.dart';
import 'package:doan/screens/scan/food_scan_screen.dart';
import '../calorie/today_intake_screen.dart';
import '../food/saved_foods_page.dart';
import '../chat/chat_ai_screen.dart';
import '../scan/calorie_scan_screen.dart';
import '../../services/intake_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthService _authService;
  String _currentUserRole = 'guest';
  bool get _isAdmin => _currentUserRole == 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  Future<void> _loadUserRole() async {
    final role = await _authServiceGetRoleSafe();
    if (mounted) setState(() => _currentUserRole = role);
  }

  Future<String> _authServiceGetRoleSafe() async {
    try {
      return await _authService.getCurrentUserRole();
    } catch (_) {
      return 'guest';
    }
  }

  Stream<int> unreadMessagesCount() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream<int>.value(0);
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        if (data['senderId'] != currentUser.uid &&
            !readBy.contains(currentUser.uid)) {
          count++;
        }
      }
      return count;
    });
  }

    String formatNumberSmart(double? v, {int decimals = 1}) {
    if (v == null) return '-';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(decimals);
  }

  Widget _caloItem(String title, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: valueColor ?? Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label,
      {required int eaten, required int goal, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '$eaten/$goal g',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  // ---------- Theme colors ----------
  static const Color pastelBackground = Color(0xFFF3F9F5);

  // ---------- Feature list ----------
  List<_Feature> get _features => [
        const _Feature('Gợi ý thực đơn', Icons.auto_awesome, DailyMenuScreen()),
        const _Feature('Scan món ăn', Icons.camera_alt, FoodScanScreen()),
        const _Feature('Món đã ăn', Icons.restaurant_menu, TodayIntakeScreen()),
        const _Feature('Món đã lưu', Icons.bookmark_rounded, SavedFoodsPage()),
        const _Feature('Scan Calo', Icons.qr_code_scanner, CalorieScanScreen()),
        const _Feature('Chat AI', Icons.smart_toy_rounded, ChatAIScreen()),
      ];

  // ---------- Custom header ----------
  Widget _buildCustomHeader(String displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Xin chào + tên
        Expanded(
          child: Text(
            'Xin chào, $displayName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Icon tin nhắn với badge
        StreamBuilder<int>(
          stream: unreadMessagesCount(),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.message_rounded, color: Colors.black87),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllMessagesScreen()),
                    );
                  },
                ),
                if (unread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.redAccent,
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Icon thông báo
        NotificationsButton(color: Colors.black),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE7F6EB),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentUser != null) ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                    // Fallback chain:
                    // 1) Firestore displayName nếu có và không rỗng
                    // 2) FirebaseAuth.currentUser.displayName nếu có và không rỗng
                    // 3) email username (phần trước @) nếu có
                    // 4) 'bạn' mặc định
                    String displayName = 'bạn';

                    final fsName = (data['displayName'] as String?)?.trim();
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
                        }
                      }
                    }

                    return _buildCustomHeader(displayName);
                  },
                ),

                const SizedBox(height: 24),
              ],

              // ===== Thông tin cơ thể + calo + macro =====
              if (currentUser != null) ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final weight = (data['weight'] as num?)?.toDouble();
                    final height = (data['height'] as num?)?.toDouble();
                    final calorieGoalData =
                        data['calorieGoal'] as Map<String, dynamic>?;
                    final int? dailyGoal = calorieGoalData?['dailyGoal'] as int?;
                    final int? bmr = calorieGoalData?['bmr'] as int?;
                    final int? tdee = calorieGoalData?['tdee'] as int?;
                    final double? bmi = (data['bmi'] as num?)?.toDouble();
                    final int? protein = calorieGoalData?['protein'] as int?;
                    final int? carbs = calorieGoalData?['carbs'] as int?;
                    final int? fat = calorieGoalData?['fat'] as int?;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 6,
                          color: const Color.fromARGB(255, 212, 241, 222),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (weight != null && height != null)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _caloItem(
                                          "Cân nặng", "${formatNumberSmart(weight)} kg"),
                                      _caloItem(
                                          "Chiều cao", "${formatNumberSmart(height)} cm"),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (bmi != null)
                                      _caloItem("BMI", bmi.toStringAsFixed(1),
                                          valueColor: Colors.deepPurple),
                                    if (bmr != null)
                                      _caloItem("BMR", "$bmr calo",
                                          valueColor: Colors.orange),
                                    if (tdee != null)
                                      _caloItem("TDEE", "$tdee calo",
                                          valueColor: Colors.green),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (dailyGoal != null &&
                                    protein != null &&
                                    carbs != null &&
                                    fat != null)
                                  StreamBuilder<double>(
                                    stream: IntakeService()
                                        .todayCaloriesTotalStream(currentUser.uid),
                                    builder: (context, caloSnap) {
                                      double eatenCalo = caloSnap.data ?? 0;
                                      double remainingCalo =
                                          (dailyGoal - eatenCalo)
                                              .clamp(0, double.infinity);
                                      double progress = (dailyGoal > 0)
                                          ? (eatenCalo / dailyGoal).clamp(0, 1)
                                          : 0;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Mục tiêu dinh dưỡng hôm nay',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 10),
                                          Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: LinearProgressIndicator(
                                                  minHeight: 28,
                                                  value: progress,
                                                  backgroundColor: Colors.green
                                                      .withAlpha(
                                                          (0.2 * 255).round()),
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: Center(
                                                  child: Text(
                                                    '${eatenCalo.round()}/$dailyGoal kcal',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          StreamBuilder<Map<String, double>>(
                                            stream: IntakeService()
                                                .todayMacrosConsumedStream(
                                                    currentUser.uid),
                                            builder: (context, macroSnap) {
                                              final eatenProtein =
                                                  macroSnap.data?['protein'] ?? 0;
                                              final eatenCarbs =
                                                  macroSnap.data?['carbs'] ?? 0;
                                              final eatenFat =
                                                  macroSnap.data?['fat'] ?? 0;

                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _macroItem(
                                                      'Protein',
                                                      eaten: eatenProtein.round(),
                                                      goal: protein,
                                                      color: Colors.purple),
                                                  _macroItem(
                                                      'Carbs',
                                                      eaten: eatenCarbs.round(),
                                                      goal: carbs,
                                                      color: Colors.blue),
                                                  _macroItem(
                                                      'Fat',
                                                      eaten: eatenFat.round(),
                                                      goal: fat,
                                                      color: Colors.orange),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),
              const Text(
                'Tiện ích hôm nay',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _buildFeatureButtonsGrid(mq),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- FEATURE GRID ----------------
  Widget _buildFeatureButtonsGrid(MediaQueryData mq) {
    final features = _features;
    double itemWidth = (mq.size.width - 64) / 3; // 16 padding *2 + 14*2 spacing
    return GridView.builder(
      itemCount: features.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: itemWidth / 120, // bự hơn
      ),
      itemBuilder: (context, index) {
        final f = features[index];
        return _FeatureSquareButton(
          title: f.title,
          icon: f.icon,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => f.destination)),
        );
      },
    );
  }
}

// ---------- feature square button widget ----------
class _FeatureSquareButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _FeatureSquareButton(
      {required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFEFF9F5);
    const Color iconBg = Color(0xFFF3FBF6);
    const Color iconColor = Color(0xFF1B8E7B);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Icon(icon, color: iconColor, size: 20)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E2E2E)),
            ),
          ),
        ],
      ),
    );
  }
}

// small model for features with concrete destination widget
class _Feature {
  final String title;
  final IconData icon;
  final Widget destination;
  const _Feature(this.title, this.icon, this.destination);
}
