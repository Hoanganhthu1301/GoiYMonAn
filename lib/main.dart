import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'services/food_service.dart';
import 'services/like_service.dart';
import 'models/food_search_state.dart';
import 'screens/account/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/push/push_bootstrap.dart';

// Top-level handler cho message khi app nền/đóng
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ------------------------
// Pastel green theme (light)
// ------------------------
final ThemeData pastelGreenTheme = ThemeData(
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8FCB9B),
    onPrimary: Colors.white,
    secondary: Color(0xFF6BBF8A),
    onSecondary: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.white,
    // dùng surface/onSurface thay cho background/onBackground (deprecated)
    surface: Color(0xFFF6FBF6),
    onSurface: Color(0xFF1F3B2E),
  ),
  fontFamily: 'Inter',
  textTheme: const TextTheme(
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 13),
  ),
  scaffoldBackgroundColor: const Color(0xFFF6FBF6),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF9DDFAF),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  // CardThemeData (sửa lỗi kiểu)
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 6,
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6BBF8A),
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF2F6B3F),
      // thay withOpacity bằng withAlpha
      side: BorderSide(color: Color(0xFF8FCB9B).withAlpha((0.6 * 255).round())),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFFF9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  ),
  dividerTheme: DividerThemeData(color: const Color(0xFFCADBC7)),
  iconTheme: const IconThemeData(color: Color(0xFF2F6B3F)),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFDFF3DF),
    labelStyle: const TextStyle(color: Color(0xFF1F3B2E)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);

// ------------------------
// Dark theme counterpart
// ------------------------
final ThemeData pastelGreenDarkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6BBF8A),
    onPrimary: Colors.black,
    secondary: Color(0xFF82D18B),
    onSecondary: Colors.black,
    error: Color(0xFFEF9A9A),
    onError: Colors.black,
    surface: Color(0xFF0F1F14),
    onSurface: Color(0xFFE7F6EB),
  ),
  scaffoldBackgroundColor: const Color(0xFF07110A),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF2E5B3B),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF0F1A12),
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF82D18B),
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0B160E),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  ),
);

// ------------------------
// ThemeNotifier (ChangeNotifier)
// ------------------------
class ThemeNotifier extends ChangeNotifier {
  bool _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;
  bool get isDark => _isDark;

  ThemeNotifier(this._isDark);

  void toggleTheme() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _isDark);
  }

  Future<void> setDark(bool value) async {
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _isDark);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCvPd_JLGFlHVyJ3WR2eCyy1YtCaHTuJ-o",
        authDomain: "goiymonan-e8fba.firebaseapp.com",
        projectId: "goiymonan-e8fba",
        storageBucket: "goiymonan-e8fba.appspot.com",
        messagingSenderId: "655103036581",
        appId: "1:655103036581:web:340738ae9bf7ae0425514c",
        measurementId: "G-DVC9S6TSWM",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  PushBootstrap.start();

  // --- Load saved theme preference BEFORE runApp ---
  final prefs = await SharedPreferences.getInstance();
  final savedIsDark = prefs.getBool('isDarkTheme') ?? false;

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FoodService>(create: (_) => FoodService()),
        Provider<LikeService>(create: (_) => LikeService()),
        ChangeNotifierProvider<FoodSearchState>(
          create: (context) => FoodSearchState(context.read<FoodService>()),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier(savedIsDark),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: 'Food Recommendation',
      theme: pastelGreenTheme,
      darkTheme: pastelGreenDarkTheme,
      themeMode: themeNotifier.mode,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) {
      return const LoginScreen();
    }
    return const DashboardScreen();
  }
}
