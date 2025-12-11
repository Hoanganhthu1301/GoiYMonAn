import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Tạo/cập nhật users/{uid} từ FirebaseAuth.User
  Future<void> ensureUserDoc(User user) async {
    final ref = userRef(user.uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'email': user.email ?? '',
        'bio': '',
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      await ref.set({
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'email': user.email ?? '',
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
  }

  /// Lắng nghe realtime hồ sơ
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return userRef(uid).snapshots().map((d) => d.data());
  }

  /// Cập nhật tên hiển thị, bio, goal, dietType, và calorieGoal (tùy chọn).
  ///
  /// - calorieGoal: map chứa các trường như 'bmr','tdee','dailyGoal','protein','carbs','fat'
  ///   Nếu calorieGoal được truyền, service sẽ lưu sub-map 'calorieGoal' AND duplicate
  ///   các trường phổ biến lên root document để dễ truy xuất.
  Future<void> updateProfile({
    required User user,
    String? displayName,
    String? bio,
    String? goal,
    String? dietType,
    Map<String, dynamic>? calorieGoal,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // displayName -> đồng bộ lên FirebaseAuth
    if (displayName != null) {
      updates['displayName'] = displayName;
      try {
        await user.updateDisplayName(displayName);
      } catch (_) {}
    }

    if (bio != null) {
      updates['bio'] = bio;
    }

    if (goal != null) {
      updates['goal'] = goal;
    }

    if (dietType != null) {
      updates['dietType'] = dietType;
    }

    if (calorieGoal != null && calorieGoal.isNotEmpty) {
      // lưu nguyên map trong sub-field
      updates['calorieGoal'] = calorieGoal;

      // duplicate những trường quan trọng lên root để các màn cũ dễ đọc
      if (calorieGoal['bmr'] != null) updates['bmr'] = calorieGoal['bmr'];
      if (calorieGoal['tdee'] != null) updates['tdee'] = calorieGoal['tdee'];
      if (calorieGoal['dailyGoal'] != null) updates['dailyGoal'] = calorieGoal['dailyGoal'];
      if (calorieGoal['protein'] != null) updates['protein'] = calorieGoal['protein'];
      if (calorieGoal['carbs'] != null) updates['carbs'] = calorieGoal['carbs'];
      if (calorieGoal['fat'] != null) updates['fat'] = calorieGoal['fat'];
    }

    await userRef(user.uid).set(updates, SetOptions(merge: true));

    // reload user to refresh displayName/photoURL in FirebaseAuth instance
    try {
      await user.reload();
    } catch (_) {}
  }

  /// Upload avatar lên Storage và cập nhật Auth + Firestore
  Future<String> uploadAvatar({required User user, required File image}) async {
    final ref = _storage.ref('users/${user.uid}/avatar.jpg');
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    await userRef(user.uid).set({
      'photoURL': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await user.updatePhotoURL(url);
      await user.reload();
    } catch (_) {}

    return url;
  }
}
