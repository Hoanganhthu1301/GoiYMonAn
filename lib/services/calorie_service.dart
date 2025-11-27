import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalorieService {
  CalorieService._();
  static final CalorieService instance = CalorieService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw Exception('User not logged in');
    }
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(_uid);

  /// Key ngày dạng yyyy-MM-dd
  String _todayKey() {
    final now = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  // LƯU MỤC TIÊU CALO HẰNG NGÀY (từ màn Tính calo)
  Future<void> saveDailyGoal({
    required int bmr,
    required int tdee,
    required int dailyGoal,
  }) async {
    await _userRef.set({
      'calorieGoal': {
        'bmr': bmr,
        'tdee': tdee,
        'dailyGoal': dailyGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  // LẤY STREAM MỤC TIÊU CALO HẰNG NGÀY
  Stream<int?> dailyGoalStream() {
    return _userRef.snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final goal = data['calorieGoal']?['dailyGoal'];
      if (goal is int) return goal;
      if (goal is num) return goal.toInt();
      return null;
    });
  }

  // THÊM MÓN ĂN VÀO NHẬT KÝ HÔM NAY
  Future<void> addFoodToToday({
    required String foodId,
    required String name,
    required int calories,
  }) async {
    final dateKey = _todayKey();

    final docRef = _userRef
        .collection('daily_intake')
        .doc(dateKey)
        .collection('items')
        .doc(foodId + DateTime.now().millisecondsSinceEpoch.toString());

    await docRef.set({
      'foodId': foodId,
      'name': name,
      'calories': calories,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // TỔNG CALO ĐÃ ĂN HÔM NAY (STREAM)
  Stream<int> todayCaloriesStream() {
    final dateKey = _todayKey();
    return _userRef
        .collection('daily_intake')
        .doc(dateKey)
        .collection('items')
        .snapshots()
        .map((snap) {
          int sum = 0;
          for (final d in snap.docs) {
            final cal = d.data()['calories'];
            if (cal is int) sum += cal;
            if (cal is num) sum += cal.toInt();
          }
          return sum;
        });
  }

  // DANH SÁCH MÓN ĐÃ ĂN HÔM NAY (STREAM)
  Stream<QuerySnapshot<Map<String, dynamic>>> todayItemsStream() {
    final dateKey = _todayKey();
    return _userRef
        .collection('daily_intake')
        .doc(dateKey)
        .collection('items')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  // XOÁ 1 MÓN TRONG NHẬT KÝ HÔM NAY
  Future<void> deleteItemToday(String itemId) async {
    final dateKey = _todayKey();
    await _userRef
        .collection('daily_intake')
        .doc(dateKey)
        .collection('items')
        .doc(itemId)
        .delete();
  }
}
