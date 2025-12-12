import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'food_detail_screen.dart';

class SavedFoodsPage extends StatelessWidget {
  const SavedFoodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Bạn cần đăng nhập để xem món đã lưu')),
      );
    }

    final savesQuery = FirebaseFirestore.instance
        .collection('user_saves')
        .doc(uid)
        .collection('foods')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Món đã lưu')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: savesQuery.snapshots(),
       builder: (context, snap) {
  if (!snap.hasData) return const Center(child: CircularProgressIndicator());

  final saveDocs = snap.data!.docs;
  final savedIds = saveDocs.map((d) => d.id).toList();

  if (savedIds.isEmpty) return const Center(child: Text('Chưa lưu món nào'));

  // 1) Lấy batch các foods tồn tại (Firebase supports whereIn with max 10 items)
  Future<void> _cleanupMissingSaves() async {
    try {
      // chia thành chunk 10 để whereIn
      final chunks = <List<String>>[];
      for (var i = 0; i < savedIds.length; i += 10) {
        chunks.add(savedIds.sublist(i, (i + 10).clamp(0, savedIds.length)));
      }

      final existingIds = <String>{};
      for (final chunk in chunks) {
        final snapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) existingIds.add(doc.id);
      }

      // tìm các id bị thiếu
      final missing = savedIds.where((id) => !existingIds.contains(id)).toList();
      if (missing.isEmpty) return;

      // xóa batch các bản ghi save (1 batch nhiều delete)
      final batch = FirebaseFirestore.instance.batch();
      final savesCol = FirebaseFirestore.instance.collection('user_saves').doc(uid).collection('foods');
      for (final id in missing) {
        batch.delete(savesCol.doc(id));
      }
      await batch.commit();
      // (không cần gọi setState — stream sẽ update tự động)
    } catch (e) {
      // optional: log error
    }
  }

  // schedule cleanup (sau frame để không xóa trong quá trình build)
  Future.microtask(() => _cleanupMissingSaves());

  // 2) Hiển thị danh sách hiện tại — dùng FutureBuilder riêng cho từng item vẫn ok,
  //    nhưng vì đã xóa các missing offline, khả năng đồng bộ cao hơn.
  return ListView.separated(
    itemCount: savedIds.length,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (context, i) {
      final foodId = savedIds[i];
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('foods').doc(foodId).get(),
        builder: (context, fs) {
          if (!fs.hasData) {
            return ListTile(
              leading: SizedBox(width: 56, height: 56, child: Center(child: CircularProgressIndicator())),
              title: const Text('Đang tải...'),
            );
          }

          // Nếu món vừa bị xoá bởi cleanup ở trên thì trả về SizedBox (item sẽ biến mất sau stream update)
          if (!fs.data!.exists) {
            return const SizedBox.shrink();
          }

          final d = fs.data!.data()!;
          final img = (d['image_url'] ?? '') as String;
          final title = (d['name'] ?? '(Không tên)').toString();
          final cal = (d['calories'] ?? '-').toString();

          return ListTile(
            leading: img.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover))
                : const Icon(Icons.image),
            title: Text(title),
            subtitle: Text('Calo: $cal'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailScreen(foodId: foodId))),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('user_saves')
                      .doc(uid)
                      .collection('foods')
                      .doc(foodId)
                      .delete();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
                }
              },
            ),
          );
        },
      );
    },
  );
},
      ),
    );
  }
} 
