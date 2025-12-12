import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart' show ProfileScreen; // <-- chỉ import ProfileScreen để tránh ambiguous import
import 'food/food_list_screen.dart';
import 'category/manage_category_page.dart';
import 'account/user_management_screen.dart';
import 'food/manage_food_page.dart';

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

      String role = (userDoc.data() as Map<String, dynamic>?)?['role'] ?? 'user';

      setState(() {
        userRole = role;

        // Nếu là admin thì có thêm trang "Quản lý"
        if (userRole == 'admin') {
          _pages = <Widget>[
            const HomeScreen(),
            FoodListScreen(),
            const ManageCategoryPage(),
            const UserManagementScreen(),
            const ManageFoodPage(),
            ProfileScreen(userId: currentUserId),
          ];
        } else {
          // User chỉ có Trang chủ và Cá nhân
          _pages = <Widget>[
            const HomeScreen(),
            FoodListScreen(),
            ProfileScreen(userId: currentUserId),
          ];
        }
      });
    } catch (e) {
      debugPrint('Lỗi lấy role: $e');
      setState(() {
        userRole = 'user';
        _pages = <Widget>[const HomeScreen(), ProfileScreen(userId: currentUserId)];
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
        selectedItemColor: const Color(0xFF1F3B2E),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
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
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Món ăn',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.category),
                  label: 'Danh mục',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Người dùng',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.article),
                  label: 'Bài viết',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Cá nhân',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Món ăn',
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
