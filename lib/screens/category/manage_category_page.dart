import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageCategoryPage extends StatefulWidget {
  const ManageCategoryPage({super.key});

  @override
  State<ManageCategoryPage> createState() => _ManageCategoryPageState();
}

class _ManageCategoryPageState extends State<ManageCategoryPage> {
  final int pageSize = 5;
  int currentPageLoaiMon = 0;
  int currentPageCheDo = 0;

  List<QueryDocumentSnapshot> loaiMonDocs = [];
  List<QueryDocumentSnapshot> cheDoDocs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final loaiMonSnapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'theo_loai_mon_an')
        .orderBy('createdAt', descending: true)
        .get();

    final cheDoSnapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'theo_che_do_an')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      loaiMonDocs = loaiMonSnapshot.docs;
      cheDoDocs = cheDoSnapshot.docs;
      loading = false;
    });
  }

  List<QueryDocumentSnapshot> _getPageItems(List<QueryDocumentSnapshot> docs, int page) {
    final start = page * pageSize;
    final end = start + pageSize > docs.length ? docs.length : start + pageSize;
    return docs.sublist(start, end);
  }

  Widget _buildCategoryList(List<QueryDocumentSnapshot> docs, int currentPage, Function(int) onPageChanged) {
    final theme = Theme.of(context);
    final pageItems = _getPageItems(docs, currentPage);

    return Column(
      children: [
        ...pageItems.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final color = data['color'] != null ? Color(data['color']) : theme.colorScheme.primary;
          final icon = data['icon'] != null ? IconData(data['icon'], fontFamily: 'MaterialIcons') : Icons.category;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: ListTile(
              leading: Icon(data['type'] == 'theo_loai_mon_an' ? icon : Icons.category, color: color),
              title: Text(data['name'], style: theme.textTheme.bodyLarge),
              subtitle: Text(data['type'] == 'theo_loai_mon_an' ? 'Phân loại món ăn' : 'Phân loại theo chế độ ăn', style: theme.textTheme.bodyMedium),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: theme.colorScheme.secondary),
                    onPressed: () {
                      
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    onPressed: () {
                      
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        // Pagination controls
        if (docs.length > pageSize)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                  child: const Text('Trước'),
                ),
                Text('Trang ${currentPage + 1} / ${(docs.length / pageSize).ceil()}'),
                TextButton(
                  onPressed: (currentPage + 1) * pageSize < docs.length ? () => onPageChanged(currentPage + 1) : null,
                  child: const Text('Sau'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý danh mục'), backgroundColor: theme.colorScheme.primary),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Danh mục theo loại món ăn', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            _buildCategoryList(loaiMonDocs, currentPageLoaiMon, (page) => setState(() => currentPageLoaiMon = page)),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Danh mục theo chế độ ăn', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            _buildCategoryList(cheDoDocs, currentPageCheDo, (page) => setState(() => currentPageCheDo = page)),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () {
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
