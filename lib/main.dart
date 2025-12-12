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
// CƠ SỞ THEME - ÁP DỤNG FONT ROBOTO
// ------------------------

// TextTheme có thể là const vì nó chỉ chứa các giá trị hằng số
const TextTheme _baseTextTheme = TextTheme(
  displayLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 57),
  displayMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 45),
  displaySmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 36),
  headlineLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 32),
  headlineMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 28),
  headlineSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 24),
  titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, fontSize: 20),
  titleMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w600, fontSize: 16),
  titleSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 14),
  bodyLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 16),
  bodyMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 14),
  bodySmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 12),
  labelLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 14),
  labelMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 12),
  labelSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 10),
);

// ------------------------
// 1. Pastel green theme (light)
// ------------------------
final ThemeData pastelGreenTheme = ThemeData(
  fontFamily: 'Roboto',
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8FCB9B),
    onPrimary: Colors.white,
    secondary: Color(0xFF6BBF8A),
    onSecondary: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.white,
    surface: Color(0xFFF6FBF6),
    onSurface: Color(0xFF1F3B2E),
  ),
  scaffoldBackgroundColor: const Color(0xFFF6FBF6),
  textTheme: _baseTextTheme.apply(
    bodyColor: const Color(0xFF1F3B2E),
    displayColor: const Color(0xFF1F3B2E),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF9DDFAF),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: _baseTextTheme.titleLarge!.copyWith(color: Colors.white),
  ),
  
  // KHẮC PHỤC LỖI: CardThemeData không phải const
  cardTheme: CardThemeData( // Xóa const ở đây
    color: Colors.white,
    elevation: 6,
    margin: const EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Xóa const ở đây
  ),
  
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6BBF8A),
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: _baseTextTheme.labelLarge!.copyWith(color: Colors.white),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF2F6B3F),
      // KHẮC PHỤC LỖI: SỬ DỤNG Color.fromARGB để tránh deprecated warning
      side: const BorderSide(color: Color.fromARGB(153, 143, 203, 155)), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: _baseTextTheme.labelLarge,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFFF9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    labelStyle: _baseTextTheme.bodyMedium!.copyWith(color: const Color(0xFF2F6B3F)), 
    hintStyle: _baseTextTheme.bodyMedium!.copyWith(color: const Color(0xFFCADBC7)),
    errorStyle: _baseTextTheme.bodySmall!.copyWith(color: const Color(0xFFCF6679)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFCADBC7)),
  iconTheme: const IconThemeData(color: Color(0xFF2F6B3F)),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFDFF3DF),
    labelStyle: _baseTextTheme.titleSmall!.copyWith(color: const Color(0xFF1F3B2E)),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);

// ------------------------
// 2. Dark theme counterpart
// ------------------------
final ThemeData pastelGreenDarkTheme = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Roboto', 
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
  textTheme: _baseTextTheme.apply(
    bodyColor: const Color(0xFFE7F6EB), 
    displayColor: const Color(0xFFE7F6EB), 
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF2E5B3B),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: _baseTextTheme.titleLarge!.copyWith(color: Colors.white),
  ),
  
  // KHẮC PHỤC LỖI: CardThemeData không phải const
  cardTheme: CardThemeData( // Xóa const ở đây
    color: const Color(0xFF0F1A12),
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), // Xóa const ở đây
  ),
  
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF82D18B),
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: _baseTextTheme.labelLarge!.copyWith(color: Colors.black),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF0B160E),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    labelStyle: _baseTextTheme.bodyMedium!.copyWith(color: const Color(0xFF82D18B)),
    hintStyle: _baseTextTheme.bodyMedium!.copyWith(color: const Color(0xFF4C6A5A)),
    errorStyle: _baseTextTheme.bodySmall!.copyWith(color: const Color(0xFFEF9A9A)),
  ),
);

// ------------------------
// ThemeNotifier (ChangeNotifier)
// ------------------------
class ThemeNotifier extends ChangeNotifier {
  // ... (Không thay đổi)
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

// ... (Hàm main, MyApp, AuthWrapper không thay đổi)

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
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier(savedIsDark),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
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