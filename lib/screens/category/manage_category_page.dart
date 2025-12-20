import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ManageCategoryPage extends StatefulWidget {
  const ManageCategoryPage({super.key});

  @override
  State<ManageCategoryPage> createState() => _ManageCategoryPageState();
}

class _ManageCategoryPageState extends State<ManageCategoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isAdmin = false;
  bool _loading = true;

  final List<IconData> availableIcons = [
    Icons.fastfood,
    Icons.local_dining,
    Icons.icecream,
    Icons.local_cafe,
    Icons.local_drink,
    Icons.rice_bowl,
    Icons.set_meal,
    Icons.cake,
    Icons.dinner_dining,
    Icons.breakfast_dining,
    Icons.emoji_food_beverage,
    Icons.local_pizza,
    Icons.local_bar,
    Icons.soup_kitchen,
    Icons.lunch_dining,
  ];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _isAdmin = data?['role'] == 'admin';
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Lỗi kiểm tra quyền admin: $e');
      setState(() {
        _isAdmin = false;
        _loading = false;
      });
    }
  }

  Future<void> _addOrEditCategory(
      {String? id, String? name, String? type, int? color, int? icon}) async {
    TextEditingController nameController = TextEditingController(text: name ?? '');
    String selectedType = type ?? 'theo_loai_mon_an';
    Color selectedColor = (color != null)
        ? Color.fromARGB(
            (color >> 24) & 0xFF, // alpha
            (color >> 16) & 0xFF, // red
            (color >> 8) & 0xFF, // green
            color & 0xFF, // blue
          )
        : Colors.green;
    IconData selectedIcon =
        IconData(icon ?? Icons.fastfood.codePoint, fontFamily: 'MaterialIcons');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(id == null ? 'Thêm danh mục' : 'Sửa danh mục'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên danh mục'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Loại danh mục'),
                    items: const [
                      DropdownMenuItem(
                          value: 'theo_loai_mon_an', child: Text('Theo loại món ăn')),
                      DropdownMenuItem(
                          value: 'theo_che_do_an', child: Text('Theo chế độ ăn')),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedType = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  if (selectedType == 'theo_loai_mon_an') ...[
                    const Text('Chọn màu:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    BlockPicker(
                      pickerColor: selectedColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text('Chọn biểu tượng:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableIcons.map((iconData) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = iconData;
                            });
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: selectedIcon == iconData
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[200],
                            child: Icon(iconData,
                                color: selectedIcon == iconData
                                    ? Colors.white
                                    : Colors.black),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final data = {
                    'name': name,
                    'type': selectedType,
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  if (selectedType == 'theo_loai_mon_an') {
                    data['color'] = selectedColor.toARGB32();
                    data['icon'] = selectedIcon.codePoint;
                  }

                  if (id == null) {
                    await _firestore.collection('categories').add(data);
                  } else {
                    await _firestore.collection('categories').doc(id).update(data);
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  Widget _buildCategoryList(String type, String title) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('categories')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chưa có danh mục $title nào.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        int pageSize = 5;
        int totalPages = (docs.length / pageSize).ceil();
        int currentPage = 0;

        return StatefulBuilder(
          builder: (context, setStatePage) {
            final start = currentPage * pageSize;
            final end = (start + pageSize > docs.length) ? docs.length : start + pageSize;
            final pageItems = docs.sublist(start, end);
            final theme = Theme.of(context);

            return Column(
              children: [
                ...pageItems.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  Color selectedColor = (data['color'] != null)
                      ? Color(data['color'])
                      : theme.colorScheme.primary;
                  final icon = IconData(data['icon'] ?? Icons.category.codePoint,
                      fontFamily: 'MaterialIcons');

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      leading: Icon(
                        type == 'theo_loai_mon_an' ? icon : Icons.category,
                        color: type == 'theo_loai_mon_an' ? selectedColor : theme.colorScheme.primary,
                      ),
                      title: Text(
                        data['name'],
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        type == 'theo_loai_mon_an'
                            ? 'Phân loại món ăn'
                            : 'Phân loại theo chế độ ăn',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurface),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: theme.colorScheme.secondary),
                            onPressed: () => _addOrEditCategory(
                              id: doc.id,
                              name: data['name'],
                              type: data['type'],
                              color: data['color'],
                              icon: data['icon'],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: theme.colorScheme.error),
                            onPressed: () => _deleteCategory(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                if (docs.length > pageSize)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: currentPage > 0
                              ? () => setStatePage(() => currentPage--)
                              : null,
                          child: Text('Trước', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                        Text(
                          'Trang ${currentPage + 1} / $totalPages',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                        TextButton(
                          onPressed: (currentPage + 1) * pageSize < docs.length
                              ? () => setStatePage(() => currentPage++)
                              : null,
                          child: Text('Sau', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập trang này.')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý danh mục'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(' Danh mục theo loại món ăn',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            _buildCategoryList('theo_loai_mon_an', 'loại món ăn'),

            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(' Danh mục theo chế độ ăn',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            _buildCategoryList('theo_che_do_an', 'chế độ ăn'),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () => _addOrEditCategory(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
