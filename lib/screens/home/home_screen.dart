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
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodySmall?.color ?? Colors.black54;
    final valColor = valueColor ?? theme.textTheme.bodyLarge?.color ?? Colors.black87;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: labelColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valColor),
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label,
      {required int eaten, required int goal, required Color color}) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodySmall?.color ?? Colors.black54;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: labelColor),
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
Widget _macroProgressRow({
  required String label,
  required int eaten,
  required int goal,
  required Color color,
}) {
  final theme = Theme.of(context);
  final textPrimary = theme.textTheme.bodyLarge?.color;
  final textSecondary = theme.textTheme.bodyMedium?.color;
  final safeGoal = (goal <= 0) ? 1 : goal; // tránh chia cho 0
  final progress = (eaten / safeGoal).clamp(0.0, 1.0);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
          Text('$eaten / $goal g', style: TextStyle(fontSize: 13, color: textSecondary)),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          minHeight: 10,
          value: progress,
          backgroundColor: color.withOpacity(0.18),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ],
  );
}

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
    final theme = Theme.of(context);
    final textColor = theme.textTheme.headlineSmall?.color ?? Colors.black87;
    final iconColor = theme.iconTheme.color ?? textColor;
    final badgeBg = theme.colorScheme.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Xin chào + tên
        Expanded(
          child: Text(
            'Xin chào, $displayName!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
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
                  icon: Icon(Icons.message_rounded, color: iconColor),
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
                      backgroundColor: badgeBg,
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
        NotificationsButton(color: Theme.of(context).iconTheme.color ?? Colors.black),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final mq = MediaQuery.of(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // pastel colors (theme-aware)
    final pastelPurple = isDark ? const Color.fromARGB(255, 53, 85, 212) : const Color.fromARGB(255, 121, 180, 248);
    final pastelOrange = isDark ? const Color.fromARGB(255, 212, 124, 56) : const Color.fromARGB(255, 248, 195, 131);
    final pastelGreen = isDark ? const Color.fromARGB(255, 81, 227, 130) : const Color.fromARGB(255, 249, 140, 207);


    // theme-aware colors
    // use surface (replacement for background per deprecation)
    final scaffoldBg = theme.colorScheme.surface;
    final softCardColor = isDark ? const Color(0xFF0F1720) : const Color.fromARGB(255, 212, 241, 222);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white70 : Colors.black87);
    final primaryColor = theme.colorScheme.primary;
    final progressBg = isDark ? Color.fromRGBO(255, 255, 255, 0.06) : const Color.fromARGB(255, 4, 60, 40).withAlpha((0.2 * 255).round());
    final progressColor = isDark ? primaryColor : Colors.green;

    return Scaffold(
      backgroundColor: scaffoldBg,
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

                    // Fallback chain for displayName
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
                          color: softCardColor,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (bmi != null)
                                  _caloItem(
                                    "BMI",
                                    bmi.toStringAsFixed(1),
                                    valueColor: pastelPurple,
                                  ),
                                if (bmr != null)
                                  _caloItem(
                                    "BMR",
                                    "$bmr calo",
                                    valueColor: pastelOrange,
                                  ),
                                if (tdee != null)
                                  _caloItem(
                                    "TDEE",
                                    "$tdee calo",
                                    valueColor: pastelGreen,
                                  ),
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
                                      double progress = (dailyGoal > 0)
                                          ? (eatenCalo / dailyGoal).clamp(0, 1)
                                          : 0;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Mục tiêu dinh dưỡng hôm nay',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary),
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
                                                  backgroundColor: progressBg,
                                                  color: progressColor,
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
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _macroProgressRow(
                                                label: 'Protein',
                                                eaten: eatenProtein.round(),
                                                goal: protein,
                                                color: const Color(0xFFD7BDE2), // pastel purple
                                              ),
                                              const SizedBox(height: 8),
                                              _macroProgressRow(
                                                label: 'Carbs',
                                                eaten: eatenCarbs.round(),
                                                goal: carbs,
                                                color: const Color(0xFFAED6F1), // pastel blue
                                              ),
                                              const SizedBox(height: 8),
                                              _macroProgressRow(
                                                label: 'Fat',
                                                eaten: eatenFat.round(),
                                                goal: fat,
                                                color: const Color(0xFFF9E79F), // pastel yellow/orange
                                              ),
                                            ],
                                          );
;
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
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),
              Text(
                'Tiện ích hôm nay',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
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
    double horizontalPadding = 16 * 2; // container padding left + right
    double spacing = 14 * 2; // approx spacing accounted (not exact, but fine)
    double itemWidth = (mq.size.width - horizontalPadding - spacing) / 3;
    return GridView.builder(
      itemCount: features.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: itemWidth / 120,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? theme.cardColor : const Color(0xFFEFF9F5);
    final iconBg = isDark ? const Color.fromRGBO(255,255,255,0.06) : const Color(0xFFF3FBF6);
    final iconColor = isDark ? theme.colorScheme.primary : const Color(0xFF1B8E7B);
    final textColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white70 : const Color(0xFF2E2E2E));

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
                    color: isDark ? Color.fromRGBO(0,0,0,0.4) : Color.fromRGBO(0,0,0,0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
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
              style: TextStyle(fontSize: 12, color: textColor),
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
