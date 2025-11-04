import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart'; 
import 'package:flutter/foundation.dart';
import 'services/auth_service.dart';
import 'services/food_service.dart'; 
import 'services/like_service.dart'; // <--- BẮT BUỘC
import 'models/food_search_state.dart'; 
import 'screens/account/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/push/push_bootstrap.dart';

// TOP-LEVEL: handler cho data-only khi app nền/đóng
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
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

  runApp(
    MultiProvider(
      providers: [
        // 1. Cung cấp AuthService
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        
        // 2. Cung cấp FoodService 
        Provider<FoodService>(
          create: (_) => FoodService(),
        ),
        
        // ==> KHẮC PHỤC LỖI: CUNG CẤP LIKESERVICE <==
        Provider<LikeService>(
          create: (_) => LikeService(),
        ),
        // ==========================================

        // 3. ChangeNotifierProvider cho Trạng thái Tìm kiếm
        ChangeNotifierProvider<FoodSearchState>(
          create: (context) => FoodSearchState(
            context.read<FoodService>(), 
          ),
        ),
        
        // 4. StreamProvider cho trạng thái Đăng nhập
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
    return MaterialApp(
      title: 'Food Recommendation',
      theme: ThemeData(primarySwatch: Colors.orange),
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
    // Lấy trạng thái USER TỪ PROVIDER
    final user = context.watch<User?>(); 

    if (user == null) {
      return const LoginScreen();
    }
    
    return const DashboardScreen();
  }
}