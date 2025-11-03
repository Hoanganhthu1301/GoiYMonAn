import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../food/food_detail_screen.dart';

class FilteredFoodsScreen extends StatefulWidget {
  final String? categoryName;

  const FilteredFoodsScreen({super.key, this.categoryName});

  @override
  State<FilteredFoodsScreen> createState() => _FilteredFoodsScreenState();
}

class _FilteredFoodsScreenState extends State<FilteredFoodsScreen> {
  String? selectedDiet;

  @override
  Widget build(BuildContext context) {
    final dietsStream = FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'theo_che_do_an') // 🔹 Lọc đúng loại chế độ ăn
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Món ăn'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // 🔸 Thanh lọc theo chế độ ăn (Chay / Mặn / ...)
          StreamBuilder<QuerySnapshot>(
            stream: dietsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Không có dữ liệu chế độ ăn'),
                );
              }

              final diets = snapshot.data!.docs;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: selectedDiet == null,
                      onSelected: (_) {
                        setState(() => selectedDiet = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ...diets.map((doc) {
                      final name = doc['name'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: selectedDiet == name,
                          onSelected: (_) {
                            setState(() =>
                                selectedDiet = selectedDiet == name ? null : name);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // 🔸 Danh sách món ăn theo lọc
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildFoodQuery(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final foods = snapshot.data!.docs;
                if (foods.isEmpty) {
                  return const Center(child: Text('Chưa có món nào.'));
                }

                return ListView.builder(
                  itemCount: foods.length,
                  itemBuilder: (context, index) {
                    final data =
                        foods[index].data() as Map<String, dynamic>? ?? {};
                    return ListTile(
                      leading: (data['image_url'] ?? '').isNotEmpty
                          ? Image.network(
                              data['image_url'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.fastfood, size: 40),
                      title: Text(data['name'] ?? ''),
                      subtitle: Text('Calo: ${data['calories'] ?? 0}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FoodDetailScreen(foodId: foods[index].id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Tạo query theo danh mục và chế độ ăn được chọn
  Stream<QuerySnapshot> _buildFoodQuery() {
    Query query = FirebaseFirestore.instance.collection('foods');

    if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
      query = query.where('categoryName', isEqualTo: widget.categoryName);
    }
    if (selectedDiet != null && selectedDiet!.isNotEmpty) {
      query = query.where('dietName', isEqualTo: selectedDiet);
    }

    return query.orderBy('created_at', descending: true).snapshots();
  }
}
