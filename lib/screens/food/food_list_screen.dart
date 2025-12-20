import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../services/like_service.dart';
import 'food_detail_screen.dart';

class FoodListScreen extends StatefulWidget {
  const FoodListScreen({super.key});

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  final _firestore = FirebaseFirestore.instance;
  late LikeService _likeSvc;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  List<DocumentSnapshot> _allFoods = [];
  List<DocumentSnapshot> _displayFoods = [];
  bool _isLoading = true;

  String searchQuery = '';
  String selectedCategory = '';
  String selectedDiet = '';

  List<String> _dietCategories = [];
  List<Map<String, dynamic>> _foodCategories = [];

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 10;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _likeSvc = context.read<LikeService>();
    _listenFoods();
    _fetchDietCategories();
    _fetchFoodCategories();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadMore();
      }
    });
  }

  Future<void> _fetchDietCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'theo_che_do_an')
          .get();
      final diets = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      if (mounted) setState(() => _dietCategories = diets);
    } catch (e) {
      debugPrint('Failed to fetch diet categories: $e');
    }
  }

  Future<void> _fetchFoodCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'theo_loai_mon_an')
          .orderBy('createdAt', descending: false)
          .get();
      final cats = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? '',
          'color': data['color'] ?? 0xFFAED581,
          'icon': data['icon'] ?? Icons.fastfood_outlined.codePoint
        };
      }).toList();
      if (mounted) setState(() => _foodCategories = cats);
    } catch (e) {
      debugPrint('Failed to fetch food categories: $e');
    }
  }

  void _listenFoods() {
    _firestore
        .collection('foods')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _allFoods = snapshot.docs;
          _currentPage = 1;
          _updatePageData();
          _isLoading = false;
        });
      },
      onError: (e) => debugPrint('listenFoods error: $e'),
    );
  }

  void _updatePageData() {
    final filtered = _allFoods.where((food) {
      final data = food.data() as Map<String, dynamic>? ?? {};
      final foodName = (data['name'] ?? '').toString().toLowerCase();
      final foodCategoryName =
          (data['categoryName'] ?? '').toString().toLowerCase();
      final foodDietName = (data['dietName'] ?? '').toString().toLowerCase();

      final matchesSearch =
          searchQuery.isEmpty || foodName.contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory.isEmpty ||
          foodCategoryName == selectedCategory.toLowerCase();
      final matchesDiet =
          selectedDiet.isEmpty || foodDietName == selectedDiet.toLowerCase();

      return matchesSearch && matchesCategory && matchesDiet;
    }).toList();

    _totalPages = (filtered.length / _pageSize).ceil();
    if (_currentPage > _totalPages && _totalPages > 0) _currentPage = _totalPages;
    if (_totalPages == 0) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (_currentPage * _pageSize < filtered.length)
        ? _currentPage * _pageSize
        : filtered.length;

    _displayFoods = filtered.sublist(
      startIndex, // dùng startIndex thay vì 0
      endIndex,
  );
  }

  void _loadMore() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
        _updatePageData();
      });
    }
  }

  Future<void> _refresh() async {
    _listenFoods();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : RefreshIndicator(
                onRefresh: _refresh,
                color: theme.colorScheme.primary,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchAndFilter(theme),
                            const SizedBox(height: 12),
                            _buildCategoryList(theme),
                            const SizedBox(height: 12),
                            _buildFoodList(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.cardColor,
              hintText: 'Tìm món ăn...',
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
        const SizedBox(width: 10),
        _buildDietFilterButton(theme),
      ],
    );
  }

Widget _buildDietFilterButton(ThemeData theme) {
  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Chọn chế độ ăn',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả', style: TextStyle(fontSize: 12)),
                  selected: selectedDiet.isEmpty,
                  selectedColor: theme.colorScheme.primary.withAlpha((0.4 * 255).toInt()),
                  backgroundColor: theme.cardColor,
                  onSelected: (_) {
                    setState(() {
                      selectedDiet = '';
                      _currentPage = 1;
                      _updatePageData();
                    });
                    Navigator.pop(context);
                  },
                ),
                ..._dietCategories.map((diet) {
                  final isSelected = selectedDiet == diet;
                  return ChoiceChip(
                    label: Text(diet, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary.withAlpha((0.4 * 255).toInt()),
                    backgroundColor: theme.cardColor,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color),
                    onSelected: (_) {
                      setState(() {
                        selectedDiet = isSelected ? '' : diet;
                        _currentPage = 1;
                        _updatePageData();
                      });
                      Navigator.pop(context);
                    },
                  );
                })
              ],
            ),
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(30),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
    ),
  );
}


  Widget _buildCategoryList(ThemeData theme) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _foodCategories.length,
        itemBuilder: (context, index) {
          final cat = _foodCategories[index];
          final color = Color(cat['color']);
          final icon = IconData(cat['icon'], fontFamily: 'MaterialIcons');
          final isSelected =
              selectedCategory.toLowerCase() == cat['name'].toString().toLowerCase();
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = isSelected ? '' : cat['name'];
                _currentPage = 1;
                _updatePageData();
              });
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
              color: isSelected ? color.withAlpha((0.3 * 255).round()) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha((0.3 * 255).round())),

              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    cat['name'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoodList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayFoods.length,
      itemBuilder: (context, index) {
        final food = _displayFoods[index];
        return _buildFoodCard(food, theme);
      },
    );
  }

  Widget _buildFoodCard(DocumentSnapshot food, ThemeData theme) {
    final data = food.data() as Map<String, dynamic>? ?? {};
    final imageUrl = (data['image_url'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FoodDetailScreen(foodId: food.id)),
      ),
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: imageUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
          color: imageUrl.isEmpty ? theme.cardColor : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(38),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withAlpha(30),
                ),
              ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Calo: ${data['calories'] ?? 0} kcal',
                    style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StreamBuilder<bool>(
                        stream: _likeSvc.isLikedStream(food.id),
                        builder: (context, s) {
                          final liked = s.data ?? false;
                          return IconButton(
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked ? Colors.pink[200] : theme.iconTheme.color,
                              size: 20,
                            ),
                            onPressed: uid == null
                                ? null
                                : () => _likeSvc.toggleLike(food.id, liked),
                          );
                        },
                      ),
                      StreamBuilder<bool>(
                        stream: _likeSvc.isSavedStream(food.id),
                        builder: (context, s) {
                          final saved = s.data ?? false;
                          return IconButton(
                            icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border_outlined,
                              color: saved ? Colors.green[200] : theme.iconTheme.color,
                              size: 20,
                            ),
                            onPressed: uid == null
                                ? null
                                : () => _likeSvc.toggleSave(food.id, saved),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
