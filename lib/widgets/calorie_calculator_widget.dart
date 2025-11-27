import 'package:flutter/material.dart';
import '../services/calorie_service.dart';

class CalorieCalculatorWidget extends StatelessWidget {
  const CalorieCalculatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final calorieService = CalorieService.instance;

    return StreamBuilder<int?>(
      stream: calorieService.dailyGoalStream(),
      builder: (context, goalSnap) {
        final dailyGoal = goalSnap.data;

        return StreamBuilder<int>(
          stream: calorieService.todayCaloriesStream(),
          builder: (context, todaySnap) {
            final eaten = todaySnap.data ?? 0;

            if (dailyGoal == null) {
              return Card(
                color: Colors.orange.shade50,
                child: const ListTile(
                  title: Text("Bạn chưa đặt mục tiêu calo"),
                  subtitle: Text("Hãy mở tính năng 'Tính calo' để cài đặt."),
                ),
              );
            }

            final remaining = dailyGoal - eaten;

            return Card(
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  "Đã ăn: $eaten / $dailyGoal kcal",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Còn lại hôm nay: ${remaining.clamp(0, 99999)} kcal",
                ),
                trailing: Icon(
                  Icons.local_fire_department,
                  color: Colors.green.shade700,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
