import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================
///  MODEL Consumption (không tách file)
/// ===============================
class Consumption {
  final String id;
  final String foodId;
  final String foodName;
  final double calories;
  final double portions;
  final DateTime consumedAt;

  Consumption({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.calories,
    required this.portions,
    required this.consumedAt,
  });
}

/// ===============================
///  SERVICE IntakeService
/// ===============================
class IntakeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ---------------------------------------------------
  /// ⭐ 1) GHI MÓN ĂN ĐÃ ĂN
  /// ---------------------------------------------------
  Future<void> addConsumption({
    required String uid,
    required String foodId,
    required String foodName,
    required double calories,
    double portions = 1,
  }) async {
    final ref = _db
        .collection("users")
        .doc(uid)
        .collection("consumptions")
        .doc();

    await ref.set({
      "foodId": foodId,
      "foodName": foodName,
      "calories": calories,
      "portions": portions,
      "createdAt": Timestamp.now(),
    });
  }

  /// ---------------------------------------------------
  /// ⭐ 2) LẤY TOÀN BỘ LỊCH SỬ MÓN ĂN
  /// ---------------------------------------------------
  Stream<List<Consumption>> allConsumptionsStream(String uid) {
    return _db
        .collection("users")
        .doc(uid)
        .collection("consumptions")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) {
            final data = d.data();
            return Consumption(
              id: d.id,
              foodId: data["foodId"] ?? "",
              foodName: data["foodName"] ?? "",
              calories: (data["calories"] ?? 0).toDouble(),
              portions: (data["portions"] ?? 1).toDouble(),
              consumedAt:
                  (data["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  /// ---------------------------------------------------
  /// ⭐ 3) LẤY LỊCH SỬ THEO NGÀY
  /// ---------------------------------------------------
  Future<List<Consumption>> consumptionsByDate(
    String uid,
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _db
        .collection("users")
        .doc(uid)
        .collection("consumptions")
        .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where("createdAt", isLessThan: Timestamp.fromDate(end))
        .orderBy("createdAt")
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return Consumption(
        id: d.id,
        foodId: data["foodId"],
        foodName: data["foodName"],
        calories: (data["calories"] ?? 0).toDouble(),
        portions: (data["portions"] ?? 1).toDouble(),
        consumedAt: (data["createdAt"] as Timestamp).toDate(),
      );
    }).toList();
  }

  /// ---------------------------------------------------
  /// ⭐ 4) TỔNG CALO HÔM NAY - realtime
  /// ---------------------------------------------------
  Stream<double> todayCaloriesTotalStream(String uid) {
    final start = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return _db
        .collection("users")
        .doc(uid)
        .collection("consumptions")
        .where("createdAt", isGreaterThan: Timestamp.fromDate(start))
        .snapshots()
        .map((snap) {
          double total = 0;
          for (var d in snap.docs) {
            final data = d.data();
            total += (data["calories"] ?? 0).toDouble();
          }
          return total;
        });
  }

  /// ---------------------------------------------------
  /// ⭐ 5) MAP DỮ LIỆU BIỂU ĐỒ CALO
  /// ---------------------------------------------------
  Map<DateTime, double> caloriesByDay(List<Consumption> all) {
    final Map<DateTime, double> result = {};

    for (var c in all) {
      final d = DateTime(
        c.consumedAt.year,
        c.consumedAt.month,
        c.consumedAt.day,
      );
      result[d] = (result[d] ?? 0) + c.calories;
    }

    return result;
  }

  /// ===========================================================
  /// ⭐⭐ 6) LƯU & LẤY CÂN NẶNG THEO THÁNG ⭐⭐
  /// ===========================================================

  /// Lưu cân nặng
  Future<void> saveWeight({
    required String uid,
    required double weight,
    required int month,
    required int year,
  }) async {
    final id = "$year-$month";

    await _db.collection("users").doc(uid).collection("weights").doc(id).set({
      "weight": weight,
      "month": month,
      "year": year,
      "updatedAt": Timestamp.now(),
    });
  }

  /// Lấy cân nặng theo tháng trong năm hiện tại
  Stream<Map<int, double>> weightByMonthStream(String uid) {
    final year = DateTime.now().year;

    return _db
        .collection("users")
        .doc(uid)
        .collection("weights")
        .where("year", isEqualTo: year)
        .snapshots()
        .map((snap) {
          final Map<int, double> m = {};
          for (var d in snap.docs) {
            final data = d.data();
            m[data["month"]] = (data["weight"] ?? 0).toDouble();
          }
          return m;
        });
  }
}
