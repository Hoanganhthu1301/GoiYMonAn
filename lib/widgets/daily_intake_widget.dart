import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/intake_service.dart';

class DailyIntakeWidget extends StatelessWidget {
  final double dailyGoal; // get from profile or CalorieCalculator result
  final VoidCallback? onViewDetails; // optional callback to open details screen

  const DailyIntakeWidget({
    super.key,
    required this.dailyGoal,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    final svc = IntakeService();

    return StreamBuilder<double>(
      stream: svc.todayCaloriesTotalStream(uid),
      initialData: 0.0,
      builder: (context, snap) {
        final consumed = snap.data ?? 0.0;
        final remaining = (dailyGoal - consumed).clamp(0.0, double.infinity);
        final pct = dailyGoal > 0
            ? (consumed / dailyGoal).clamp(0.0, 1.0)
            : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Hôm nay',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('${remaining.toStringAsFixed(0)} kcal còn lại'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  color: pct >= 1.0 ? Colors.red : Colors.green,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Đã ăn: ${consumed.toStringAsFixed(0)} kcal'),
                    const Spacer(),
                    Text('Mục tiêu: ${dailyGoal.toStringAsFixed(0)} kcal'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.list),
                      label: const Text('Chi tiết'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        // You might implement “undo last” here by removing last doc
                        // For safety you need to show list details screen first
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mở chi tiết để hoàn tác.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Hoàn tác'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
