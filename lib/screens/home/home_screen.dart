import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/like_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/notifications_button.dart';
import '../../core/push/push_service_min.dart';
import '../food/add_food_page.dart';
import '../food/food_detail_screen.dart';
import '../food/saved_foods_page.dart';
import '../chat/all_message.dart';
import '../food/filtered_foods_screen.dart';
import 'package:doan/screens/menu/daily_menu_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  late LikeService _likeSvc;
  late AuthService _authService;
  final _push = PushServiceMin();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _push.init(context: context);
    });
    _listenFoods();
    _fetchDietCategories();
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

  // Realtime listener cho foods
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
Stream<int> unreadMessagesCount() {
  final currentUser = FirebaseAuth.instance.currentUser!;
  return FirebaseFirestore.instance
      .collection('messages')
      .where('participants', arrayContains: currentUser.uid)
      .snapshots()
      .map((snapshot) {
    int count = 0;
    for (var doc in snapshot.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(currentUser.uid)) count++;
    }
    return count;
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
      final foodCategoryName = (data['categoryName'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final foodDietName = (data['dietName'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      debugPrint(
        'Filtering food: ${data['name']} - Category: $foodCategoryName - Diet: $foodDietName',
      );
      debugPrint('Selected: Category=$selectedCategory, Diet=$selectedDiet');

      final matchesSearch =
          searchQuery.isEmpty ||
          foodName.contains(searchQuery.toLowerCase().trim());

      final matchesCategory =
          selectedCategory.isEmpty ||
          foodCategoryName == selectedCategory.toLowerCase().trim();

      final matchesDiet =
          selectedDiet.isEmpty ||
          foodDietName == selectedDiet.toLowerCase().trim();

      return matchesSearch && matchesCategory && matchesDiet;
    }).toList();

    _totalPages = (filtered.length / _pageSize).ceil();

    if (_currentPage > _totalPages && _totalPages > 0) {
      _currentPage = _totalPages;
    }

    if (_totalPages == 0) {
      _currentPage = 1;
    }

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
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.green,
        centerTitle: true,
        // Thay thế phần StreamBuilder hiện tại trong AppBar actions:
        actions: [
        if (!_isAdmin)
            // Thêm StreamBuilder badge tin nhắn
        StreamBuilder<int>(
          stream: unreadMessagesCount(),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.message),
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
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
          : Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm món ăn...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _currentPage = 1;
                        _updatePageData();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _dietCategories.isEmpty
                      ? const CircularProgressIndicator()
                      : DropdownButton<String>(
                          value: selectedDiet.isEmpty ? null : selectedDiet,
                          hint: const Text('Chọn chế độ ăn'),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(value: '', child: Text('Tất cả')),
                            ..._dietCategories.map(
                              (diet) => DropdownMenuItem(
                                value: diet,
                                child: Text(diet),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedDiet = value ?? '';
                              _currentPage = 1;
                              _updatePageData();
                            });
                          },
                        ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                        .collection('categories')
                        .where('type', isEqualTo: 'theo_loai_mon_an')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final categories = snapshot.data!.docs;
                        if (categories.isEmpty) return const Center(child: Text('Chưa có danh mục món ăn nào.'));

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index].data() as Map<String, dynamic>;
                            
                            final colorInt = cat['color'] ?? 0xFF4CAF50;
                            final color = Color.fromARGB(
                              (colorInt >> 24) & 0xFF,
                              (colorInt >> 16) & 0xFF,
                              (colorInt >> 8) & 0xFF,
                              colorInt & 0xFF,
                            );

                            final iconCode = cat['icon'] ?? Icons.fastfood.codePoint;
                            final icon = IconData(iconCode, fontFamily: 'MaterialIcons');

                            return _buildFoodCategory(
                              cat['name'] ?? 'Danh mục',
                              icon,
                              color,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFeatureCard(
                          'Gợi ý Thực đơn', // Tiêu đề
                          Icons.auto_awesome, // Icon
                          Colors.teal, // Màu
                          () {
                            // Hành động
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyMenuScreen(),
                              ),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          'Đã lưu',
                          Icons.bookmark,
                          Colors.blueGrey,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SavedFoodsPage(),
                            ),
                          ),
                        ),
                        _buildFeatureCard(
                          'Thêm món',
                          Icons.add,
                          Colors.orange,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddFoodPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        _listenFoods(); // làm mới dữ liệu
                      },
                      child: ListView.builder(
                        itemCount: _displayFoods.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _displayFoods.length) {
                            return _buildPagination();
                          }
                          final food = _displayFoods[index];
                          return _buildFoodCard(food);
                        },
                      ),
                    ),
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
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _changePage(_currentPage - 1)
                : null,
          ),
          ...List.generate(_totalPages, (i) {
            final page = i + 1;
            return GestureDetector(
              onTap: () => _changePage(page),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentPage == page ? Colors.green : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    color: _currentPage == page ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _changePage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(DocumentSnapshot food) {
    final data = food.data() as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: ListTile(
        leading: (data['image_url'] ?? '').isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  data['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.fastfood, size: 40),
        title: Text(data['name'] ?? ''),
        subtitle: Text(
          'Calo: ${data['calories'] ?? 0} kcal | Chế độ: ${data['diet'] ?? ''}',
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
                  tooltip: liked ? 'Bỏ thích' : 'Thích',
                  onPressed: uid == null
                      ? null
                      : () => _likeSvc.toggleLike(food.id, liked),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.pink : Colors.grey,
                  ),
                );
              },
            ),
            StreamBuilder<int>(
              stream: _likeSvc.likesCount(food.id),
              builder: (context, s) {
                final count = s.data ?? 0;
                return Text('$count', style: const TextStyle(fontSize: 12));
              },
            ),
            const SizedBox(width: 8),
            StreamBuilder<bool>(
              stream: _likeSvc.isSavedStream(food.id),
              initialData: false,
              builder: (context, s) {
                final saved = s.data ?? false;
                return IconButton(
                  tooltip: saved ? 'Bỏ lưu' : 'Lưu',
                  onPressed: uid == null
                      ? null
                      : () => _likeSvc.toggleSave(food.id, saved),
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color.withAlpha(25),
        margin: const EdgeInsets.only(right: 10),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
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
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(128) : color.withAlpha(51),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              categoryName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}  