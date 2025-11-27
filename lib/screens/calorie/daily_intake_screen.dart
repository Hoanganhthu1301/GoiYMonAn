import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/calorie_service.dart';

class DailyIntakeScreen extends StatelessWidget {
  const DailyIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CalorieService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký ăn uống hôm nay'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.todayItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text('Hôm nay bạn chưa ghi nhận món nào.'),
            );
          }

          int total = 0;
          for (final d in docs) {
            final cal = d.data()['calories'];
            if (cal is int) total += cal;
            if (cal is num) total += cal.toInt();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Tổng hôm nay: $total kcal',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = data['name'] ?? 'Món ăn';
                    final calories = data['calories'] ?? 0;

                    return Dismissible(
                      key: ValueKey(d.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        service.deleteItemToday(d.id);
                      },
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text('$calories kcal'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
