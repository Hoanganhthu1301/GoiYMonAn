import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/recommendation_service.dart';
import '../food/food_detail_screen.dart';

class DailyMenuScreen extends StatefulWidget {
  const DailyMenuScreen({super.key});

  @override
  State<DailyMenuScreen> createState() => _DailyMenuScreenState();
}

class _DailyMenuScreenState extends State<DailyMenuScreen> {
  Future<Map<String, DocumentSnapshot?>> _menuFuture = Future.value({});
  final RecommendationService _recommendationService = RecommendationService();

  Map<String, DocumentSnapshot?> lockedMeals = {
    'main': null,
    'side': null,
    'appetizer': null,
    'dessert': null,
  };

  static const Map<String, String> titleToKey = {
    'Món chính': 'main',
    'Món phụ': 'side',
    'Khai vị': 'appetizer',
    'Tráng miệng': 'dessert',
  };

  @override
  void initState() {
    super.initState();
    _menuFuture = _loadLockedMeals().then((_) async {
      final savedMenu = await _loadSavedMenu();
      bool hasSaved = savedMenu.values.any((doc) => doc != null);
      if (hasSaved) return savedMenu;

      final newMenu = await _recommendationService.getDailyMenu();
      await _saveMenu(newMenu);
      return newMenu;
    });
  }

  Future<void> _loadLockedMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final foodsCollection = FirebaseFirestore.instance.collection('foods');
    for (var key in lockedMeals.keys) {
      final id = prefs.getString('locked_$key');
      if (id != null && id.isNotEmpty) {
        final doc = await foodsCollection.doc(id).get();
        if (doc.exists) {
          lockedMeals[key] = doc;
        }
      }
    }
  }

  Future<void> _saveLockedMeal(String key, String? foodId) async {
    final prefs = await SharedPreferences.getInstance();
    if (foodId != null) {
      await prefs.setString('locked_$key', foodId);
    } else {
      await prefs.remove('locked_$key');
    }
  }

  Future<void> _saveMenu(Map<String, DocumentSnapshot?> menu) async {
    final prefs = await SharedPreferences.getInstance();
    for (var key in menu.keys) {
      final doc = menu[key];
      if (doc != null && doc.exists) {
        await prefs.setString('saved_$key', doc.id);
      } else {
        await prefs.remove('saved_$key');
      }
    }
  }

  Future<Map<String, DocumentSnapshot?>> _loadSavedMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final foodsCollection = FirebaseFirestore.instance.collection('foods');
    Map<String, DocumentSnapshot?> savedMenu = {
      'main': null,
      'side': null,
      'appetizer': null,
      'dessert': null,
    };

    for (var key in savedMenu.keys) {
      final id = prefs.getString('saved_$key');
      if (id != null && id.isNotEmpty) {
        final doc = await foodsCollection.doc(id).get();
        if (doc.exists) savedMenu[key] = doc;
      }
    }

    return savedMenu;
  }

  void _reloadMenu() async {
    final newMenu = await _recommendationService.getDailyMenu();
    newMenu.forEach((key, value) {
      if (lockedMeals[key] != null) newMenu[key] = lockedMeals[key];
    });
    await _saveMenu(newMenu);
    setState(() {
      _menuFuture = Future.value(newMenu);
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Chào buổi sáng!';
    if (h < 15) return 'Chúc buổi trưa ngon miệng! ';
    if (h < 18) return 'Chúc buổi chiều tốt lành! ';
    return 'Buổi tối an lành nhé ';
  }

  Widget _buildMealCard(BuildContext context, String title, IconData icon, DocumentSnapshot? foodDoc) {
    final key = titleToKey[title] ?? title;
    final isLocked = lockedMeals[key] == foodDoc && foodDoc != null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.grey.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (foodDoc != null && foodDoc.exists)
                  IconButton(
                    icon: Icon(isLocked ? Icons.lock : Icons.lock_open, color: isLocked ? Colors.green : Colors.grey),
                    onPressed: () {
                      setState(() {
                        if (isLocked) {
                          lockedMeals[key] = null;
                          _saveLockedMeal(key, null);
                        } else {
                          lockedMeals[key] = foodDoc;
                          _saveLockedMeal(key, foodDoc.id);
                        }
                      });
                    },
                    tooltip: isLocked ? 'Bỏ giữ món' : 'Giữ món',
                  ),
              ],
            ),
            const Divider(height: 20),
            if (foodDoc != null && foodDoc.exists) ...[
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailScreen(foodId: foodDoc.id)));
                },
                child: Builder(
                  builder: (_) {
                    final data = foodDoc.data() as Map<String, dynamic>? ?? {};
                    final imageUrl = (data['image_url'] ?? data['imageUrl']) as String? ?? '';
                    final name = data['name'] as String? ?? 'Món ăn';
                    final calories = data['calories']?.toString() ?? '0';
                    return Row(
                      children: [
                        imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover),
                              )
                            : Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.fastfood, color: Colors.grey),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('$calories kcal', style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(data['dietName'] ?? '', overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    );
                  },
                ),
              ),
            ] else ...[
              const Text('Không tìm thấy món phù hợp với sở thích của bạn cho bữa này. Hãy thử lưu thêm món nhé!', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thực đơn gợi ý hôm nay"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reloadMenu, tooltip: "Gợi ý thực đơn khác"),
        ],
      ),
      body: FutureBuilder<Map<String, DocumentSnapshot?>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Lỗi tải gợi ý: ${snapshot.error}")),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Không có gợi ý nào."));
          }

          final menu = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reloadMenu(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Mình đã chọn sẵn 4 món phù hợp cho hôm nay. Bạn có thể giữ món yêu thích để không bị thay khi gợi ý mới.', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                _buildMealCard(context, 'Món chính', Icons.restaurant, menu['main']),
                const SizedBox(height: 16),
                _buildMealCard(context, 'Món phụ', Icons.rice_bowl, menu['side']),
                const SizedBox(height: 16),
                _buildMealCard(context, 'Khai vị', Icons.local_dining, menu['appetizer']),
                const SizedBox(height: 16),
                _buildMealCard(context, 'Tráng miệng', Icons.icecream, menu['dessert']),

                const SizedBox(height: 20),
                Center(
                  child: Text('Chúc bạn có một ngày đầy năng lượng và món ngon hợp khẩu vị!', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
