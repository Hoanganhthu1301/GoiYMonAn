
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'food/manage_food_page.dart'; // Trang quản lý (admin)
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'dashboard_screen.dart';

import 'category/manage_category_page.dart';
import 'account/user_management_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'dashboard_screen.dart';
import 'menu/daily_menu_screen.dart';
import 'food/saved_foods_page.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  String userRole = ''; // admin hoặc user
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      String role = userDoc['role'] ?? 'user';

      setState(() {
        userRole = role;

        // 👉 Nếu là admin thì có thêm trang "Quản lý"
        if (userRole == 'admin') {
          _pages = [
            const HomeScreen(),
            const ManageFoodPage(),
            const UserManagementScreen(),
            const ManageCategoryPage(),
            ProfileScreen(userId: currentUserId),
          ];
        } else {
          // 👉 User chỉ có Trang chủ và Cá nhân
          _pages = [
            const HomeScreen(),
            const DailyMenuScreen(),
            const SavedFoodsPage(),
            ProfileScreen(userId: currentUserId),

            ];
        }
      });
    } catch (e) {
    debugPrint('Lỗi lấy role: $e');
      setState(() {
        userRole = 'user';
        _pages = [const HomeScreen(), ProfileScreen(userId: currentUserId)];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userRole.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey, // màu cho icon chưa chọn
          showUnselectedLabels: true,       // 🔹 luôn hiện label cho icon chưa chọn
          type: BottomNavigationBarType.fixed, // 🔹 giữ cố định layout
                onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
items: userRole == 'admin'
    ? const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.article),
          label: 'Bài viết',
        ),
                BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Người dùng',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.category),
          label: 'Danh mục',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Cá nhân',
        ),
      ]
    : const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label:' Trang chủ',

        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome),
          label: 'Gợi ý',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'Đã lưu',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Cá nhân',
        ),
      ],
      ),
    );
  }
}
