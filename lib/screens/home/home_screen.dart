// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/like_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/notifications_button.dart';
import '../../core/push/push_service_min.dart';
import '../food/food_detail_screen.dart';
import '../chat/all_message.dart';
import '../food/filtered_foods_screen.dart';
import '../../services/message_service.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  //  @override
  // void initState() {
  //   super.initState();
  //   _printIdToken(); // 👈 Lấy token khi vào màn hình
  // }

  final _firestore = FirebaseFirestore.instance;
  late LikeService _likeSvc;
  late AuthService _authService;
  final _push = PushServiceMin();
  final _msgSvc = MessageService();

  List<DocumentSnapshot> _allFoods = [];
  List<DocumentSnapshot> _displayFoods = [];
  bool _isLoading = true;

  String searchQuery = '';
  String selectedCategory = '';
  String selectedDiet = '';

  String _currentUserRole = 'guest';
  bool get _isAdmin => _currentUserRole == 'admin';
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  static const int _pageSize = 5;
  int _currentPage = 1;
  int _totalPages = 1;

  List<String> _dietCategories = [];

  Future<void> _printIdToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No user is currently signed in.");
      return;
    }

    // Lấy token mới nhất
    final String token = (await user.getIdToken(true))!;


    // Copy vào clipboard
    await Clipboard.setData(ClipboardData(text: token));

    print("===========================================");
    print("🔥 FIREBASE ID TOKEN (đã copy vào clipboard):");
    print(token);
    print("===========================================");
    print("👉 Bạn chỉ cần Ctrl+V vào Postman là ra full token.");
  } catch (e) {
    print("❌ Error fetching ID token: $e");
  }
}

Future<void> printFreshToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("⚠ No user signed in");
    return;
  }

  final token = await user.getIdToken(true); // ★ ép tạo token mới
  print("🔥 NEW TOKEN:");
  print(token);
}
Future<void> copyIdToken() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("❌ User chưa đăng nhập");
    return;
  }

  // Lấy token mới nhất (ép refresh)
  final token = await user.getIdToken(true);

  // Copy vào clipboard
await Clipboard.setData(ClipboardData(text: token ?? ""));


  print("🔥 FULL ID TOKEN đã copy vào clipboard!");
  print("Bạn có thể dán vào Postman hoặc bất kỳ đâu.");
}
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _push.init(context: context);
    });
    _listenFoods();
    _fetchDietCategories();
    _printIdToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = context.read<AuthService>();
    _likeSvc = context.read<LikeService>();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  void _listenFoods() {
    _firestore
        .collection('foods')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _allFoods = snapshot.docs;
        _updatePageData();
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchDietCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'theo_che_do_an')
          .get();
      final diets = snapshot.docs.map((doc) => doc['name'].toString()).toList();

      if (mounted) {
        setState(() {
          _dietCategories = diets;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch diet categories: $e');
    }
  }

  void _updatePageData() {
    List<DocumentSnapshot> filtered = _allFoods.where((food) {
      final data = food.data() as Map<String, dynamic>? ?? {};

      final foodName = (data['name'] ?? '').toString().toLowerCase().trim();
      final foodCategoryName =
          (data['categoryName'] ?? '').toString().toLowerCase().trim();
      final foodDietName =
          (data['dietName'] ?? '').toString().toLowerCase().trim();

      final matchesSearch =
          searchQuery.isEmpty || foodName.contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory.isEmpty || foodCategoryName == selectedCategory;
      final matchesDiet = selectedDiet.isEmpty ||
        foodDietName.toLowerCase() == selectedDiet.toLowerCase();


      return matchesSearch && matchesCategory && matchesDiet;
    }).toList();

    _totalPages = (filtered.length / _pageSize).ceil();
    if (_currentPage > _totalPages && _totalPages > 0) {
      _currentPage = _totalPages;
    }
    if (_totalPages == 0) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (_currentPage * _pageSize < filtered.length)
        ? _currentPage * _pageSize
        : filtered.length;
    _displayFoods = filtered.sublist(startIndex, endIndex);
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _updatePageData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trang chủ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.key, color: Colors.black),
            tooltip: "In token",
            onPressed: _printIdToken, // 👈 gọi hàm lấy token
          ),
          IconButton(
      icon: const Icon(Icons.content_copy, color: Colors.black),
      tooltip: "Copy ID token",
      onPressed: _printIdToken,
    ),

          if (!_isAdmin)
            StreamBuilder<int>(
              stream: _msgSvc.unreadCountStream(),
              builder: (context, snapshot) {
                final unread = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.black87),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllMessagesScreen()),
                        );
                      },
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const NotificationsButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
// 🔍 Thanh tìm kiếm + nút lọc chế độ ăn
Row(
  children: [
    // Ô tìm kiếm
    Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          decoration: const InputDecoration(
            hintText: 'Tìm món ăn...',
            prefixIcon: Icon(Icons.search, color: Colors.black54),
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onChanged: (value) {
            setState(() {
              searchQuery = value;
              _currentPage = 1;
              _updatePageData();
            });
          },
        ),
      ),
    ),

    const SizedBox(width: 10),

    GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn chế độ ăn',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: selectedDiet.isEmpty,
                      selectedColor: Colors.green.withValues(alpha: 0.3),
                      onSelected: (_) {
                        setState(() {
                          selectedDiet = '';
                          _updatePageData();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ..._dietCategories.map((diet) {
                      final isSelected = selectedDiet == diet;
                      return ChoiceChip(
                        label: Text(diet),
                        selected: isSelected,
                        selectedColor: Colors.green.withValues(alpha: 0.3),
                        onSelected: (_) {
                          setState(() {
                            selectedDiet = diet;
                            _updatePageData();
                          });
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.tune, color: Colors.green),
      ),
    ),
  ],
),


                  const SizedBox(height: 20),

                  // 🌿 Danh mục loại món
                  SizedBox(
                    height: 100,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('categories')
                          .where('type', isEqualTo: 'theo_loai_mon_an')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final categories = snapshot.data!.docs;
                        if (categories.isEmpty) {
                          return const Center(
                              child: Text('Chưa có danh mục món ăn nào.'));
                        }
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index].data()
                                as Map<String, dynamic>;
                            final colorInt = cat['color'] ?? 0xFFA5D6A7;
                            final color = Color(colorInt);
                            final iconCode = cat['icon'] ??
                                Icons.fastfood_outlined.codePoint;
                            final icon =
                                IconData(iconCode, fontFamily: 'MaterialIcons');
                            return _buildFoodCategory(
                                cat['name'] ?? 'Danh mục', icon, color);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🌈 Banner giữa trang
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha:0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 30,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Khám phá món mới hôm nay 🍽️',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Ăn lành mạnh - sống năng lượng 💚',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📋 Danh sách món ăn
                  ListView.builder(
                    itemCount: _displayFoods.length + 1,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (index == _displayFoods.length) {
                        return _buildPagination();
                      }
                      final food = _displayFoods[index];
                      return _buildFoodCard(food);
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (i) {
          final page = i + 1;
          return GestureDetector(
            onTap: () => _changePage(page),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentPage == page
                    ? const Color(0xFF81C784)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$page',
                style: TextStyle(
                  color:
                      _currentPage == page ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFoodCard(DocumentSnapshot food) {
    final data = food.data() as Map<String, dynamic>? ?? {};
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: (data['image_url'] ?? '').isNotEmpty
              ? Image.network(
                  data['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 60,
                  height: 60,
                  color: Colors.green[100],
                  child:
                      const Icon(Icons.fastfood_outlined, color: Colors.green),
                ),
        ),
        title: Text(
          data['name'] ?? '',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Calo: ${data['calories'] ?? 0} kcal | Chế độ: ${data['diet'] ?? ''}',
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FoodDetailScreen(foodId: food.id)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<bool>(
              stream: _likeSvc.isLikedStream(food.id),
              initialData: false,
              builder: (context, s) {
                final liked = s.data ?? false;
                return IconButton(
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.pinkAccent : Colors.grey,
                  ),
                  onPressed: uid == null
                      ? null
                      : () => _likeSvc.toggleLike(food.id, liked),
                );
              },
            ),
            StreamBuilder<bool>(
              stream: _likeSvc.isSavedStream(food.id),
              initialData: false,
              builder: (context, s) {
                final saved = s.data ?? false;
                return IconButton(
                  icon: Icon(
                    saved
                        ? Icons.bookmark
                        : Icons.bookmark_border_outlined,
                    color: saved ? Colors.green : Colors.grey,
                  ),
                  onPressed: uid == null
                      ? null
                      : () => _likeSvc.toggleSave(food.id, saved),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCategory(String categoryName, IconData icon, Color color) {
    final isSelected = selectedCategory == categoryName;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FilteredFoodsScreen(categoryName: categoryName),
          ),
        );
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha:0.3) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha:0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(
              categoryName,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
