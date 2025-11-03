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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snap.data!.docs.map((d) => d.id).toList();
          if (ids.isEmpty) {
            return const Center(child: Text('Chưa lưu món nào'));
          }
          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final foodId = ids[i];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('foods')
                    .doc(foodId)
                    .get(),
                builder: (context, fs) {
                  if (!fs.hasData) {
                    return const ListTile(
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(),
                      ),
                      title: Text('Đang tải...'),
                    );
                  }
                  if (!fs.data!.exists) {
                    return ListTile(
                      title: Text('Món ($foodId) không còn tồn tại'),
                      trailing: const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                      ),
                    );
                  }
                  final d = fs.data!.data()!;
                  final img = (d['image_url'] ?? '') as String;
                  final title = (d['name'] ?? '(Không tên)').toString();
                  final cal = (d['calories'] ?? '-').toString();
                  return ListTile(
                    leading: img.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              img,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image),
                    title: Text(title),
                    subtitle: Text('Calo: $cal'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodDetailScreen(foodId: foodId),
                        ),
                      );
                    },
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
