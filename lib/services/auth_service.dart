// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart'; // KHÔI PHỤC IMPORT GOOGLE
import '../models/app_user.dart'; 
import 'fcm_token_service.dart'; 

// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages, avoid_print

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance; 
  // KHÔI PHỤC KHAI BÁO GOOGLE SIGN-IN
  final GoogleSignIn _googleSignIn = GoogleSignIn(); 

  // Hàm tiện ích hiển thị lỗi
  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // =================================================================
  // ĐĂNG KÝ VÀ PHÂN QUYỀN BAN ĐẦU
  // =================================================================
  
  Future<User?> register(
    String email, 
    String password, [
    String? displayName,
  ]) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      final String finalDisplayName = displayName ?? email.split('@')[0];

      if (user != null) {
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
        
        // LƯU THÔNG TIN VÀ VAI TRÒ VÀO FIRESTORE (PHÂN QUYỀN)
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'role': 'user', // Gán vai trò mặc định
          'isLocked': false, // Mặc định không khóa
          'displayName': finalDisplayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Fluttertoast.showToast(msg: 'Đăng ký thành công!');
      return user;
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Lỗi đăng ký');
      return null;
    } catch (e) {
      debugPrint('Lỗi đăng ký không xác định: $e');
      return null;
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      // một số code phổ biến: invalid-email, user-not-found, too-many-requests
      return e.message ?? 'Lỗi gửi mail đặt lại mật khẩu';
    } catch (e) {
      return 'Lỗi: $e';
    }
  }


  // =================================================================
  // ĐĂNG NHẬP (EMAIL/PASSWORD VÀ KHÓA TÀI KHOẢN)
  // =================================================================
  
  Future<User?> login(String email, String password) async {
    try {
      // LOGIC FCM: XÓA TOKEN CŨ (Nếu có user đang đăng nhập khác)
      if (_auth.currentUser != null) {
        try {
          await FcmTokenService().unlinkAndDeleteToken();
        } catch (e) { 
          debugPrint('Lỗi xóa token cũ khi chuyển đổi user: $e'); 
        }
      }
      
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;

      if (user != null) {
        // KIỂM TRA TRẠNG THÁI KHÓA TỪ FIRESTORE
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();

        if (doc.exists && doc.data() is Map<String, dynamic>) {
          if ((doc.data() as Map<String, dynamic>)['isLocked'] == true) {
            await _auth.signOut(); // Bắt buộc đăng xuất khỏi Firebase
            _showError('Tài khoản của bạn đã bị khóa bởi quản trị viên.');
            return null;
          }
        }
      }
      
      Fluttertoast.showToast(msg: 'Đăng nhập thành công!');
      return user;
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Lỗi đăng nhập');
      return null;
    } catch (e) {
      _showError('Lỗi không xác định: $e');
      return null;
    }
  }

  // =================================================================
  // ĐĂNG NHẬP BẰNG NHÀ CUNG CẤP BÊN NGOÀI (SOCIAL SIGN-IN)
  // =================================================================
  
  // KHÔI PHỤC Đăng nhập bằng Google
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Mở giao diện chọn tài khoản (Dùng biến thành viên _googleSignIn)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn(); 
      
      if (googleUser == null) {
        Fluttertoast.showToast(msg: "Đăng nhập Google bị hủy.");
        return null;
      }

      // 2. Lấy chi tiết xác thực (SỬ DỤNG .authentication, CÚ PHÁP CHUẨN)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 3. Tạo credential Firebase (SỬ DỤNG CÚ PHÁP CƠ BẢN)
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, // Cú pháp chuẩn
        idToken: googleAuth.idToken,        // Cú pháp chuẩn
      );

      // 4. Đăng nhập vào Firebase với Credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) return null;

      // 5. Kiểm tra và tạo document người dùng
      // KIỂM TRA TRẠNG THÁI KHÓA TỪ FIRESTORE
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() is Map<String, dynamic>) {
        if ((doc.data() as Map<String, dynamic>)['isLocked'] == true) {
          // Buộc đăng xuất khỏi cả Firebase VÀ Google nếu bị khóa
          await _auth.signOut(); 
          await _googleSignIn.signOut(); // Đăng xuất khỏi biến thành viên
          _showError('Tài khoản Google của bạn đã bị khóa bởi quản trị viên.');
          return null;
        }
      }
      
      // TẠO DOCUMENT NẾU CHƯA CÓ
      if (!doc.exists) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'role': 'user', 
          'isLocked': false, 
          'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Người dùng',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Fluttertoast.showToast(msg: 'Đăng nhập Google thành công!');
      return user;

    } on FirebaseAuthException catch (e) {
      _showError("Lỗi đăng nhập Google: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("Lỗi đăng nhập Google: $e");
      return null;
    }
  }


  // KHÔI PHỤC Đăng nhập bằng GitHub
  Future<User?> signInWithGitHub() async {
    try {
      // 1. BUỘC ĐĂNG XUẤT TRƯỚC KHI MỞ LUỒNG MỚI 
      if (_auth.currentUser != null) {
          await _auth.signOut(); 
      }

      // 2. Tạo nhà cung cấp GitHub
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      
      // 3. Yêu cầu Firebase mở luồng xác thực GitHub
      final UserCredential userCredential = await _auth.signInWithProvider(githubProvider); 
      final User? user = userCredential.user;

      if (user != null) {
        // 4. KIỂM TRA/TẠO DOCUMENT USER VÀ LƯU PHÂN QUYỀN VÀO FIRESTORE
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
        
        // KIỂM TRA KHÓA TÀI KHOẢN
        if (doc.exists && doc.data() is Map<String, dynamic>) {
          if ((doc.data() as Map<String, dynamic>)['isLocked'] == true) {
            await _auth.signOut(); 
            _showError('Tài khoản GitHub của bạn đã bị khóa bởi quản trị viên.');
            return null;
          }
        }
        
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'role': 'user', 
            'isLocked': false, 
            'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Người dùng',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      _showError("Đăng nhập bằng GitHub thành công!"); 
      return user;

    } on FirebaseAuthException catch (e) {
      _showError("Lỗi đăng nhập GitHub: ${e.message}");
      return null;
    } catch (e) {
      _showError("Lỗi hệ thống GitHub Sign-in: $e");
      return null;
    }
  }

  // Hàm Đăng nhập Ẩn danh (Giữ nguyên)
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      final User? user = userCredential.user;

      if (user != null) {
        // KIỂM TRA/TẠO DOCUMENT USER TRONG FIRESTORE
        DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();

        // KIỂM TRA KHÓA TÀI KHOẢN 
        if (doc.exists && doc.data() is Map<String, dynamic>) {
          if ((doc.data() as Map<String, dynamic>)['isLocked'] == true) {
            await _auth.signOut(); 
            _showError('Tài khoản ẩn danh này đã bị khóa bởi quản trị viên.');
            return null;
          }
        }

        if (!doc.exists) {
          // Nếu chưa tồn tại, tạo Document user mới với role 'user'
          await _db.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? 'Ẩn danh',
            'role': 'user', 
            'isLocked': false, 
            'displayName': 'Người dùng ẩn danh',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      _showError("Đăng nhập ẩn danh thành công!");
      return user;
    } on FirebaseAuthException catch (e) {
      _showError("Lỗi đăng nhập ẩn danh: ${e.message}");
      return null;
    } catch (e) {
      _showError("Lỗi hệ thống: $e");
      return null;
    }
  }

  // =================================================================
  // CÁC HÀM PHÂN QUYỀN VÀ QUẢN LÝ USER
  // =================================================================
  
  // Lấy vai trò (role) của người dùng hiện tại
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'guest';
    }
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() is Map<String, dynamic>) {
        return (doc.data() as Map<String, dynamic>)['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      debugPrint("Error getting user role: $e");
      return 'user';
    }
  }

  Stream<List<AppUser>> getUsers() {
    return _db.collection('users')
      .snapshots()
      .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppUser.fromFirestore(doc.data()); 
      }).toList();
    });
  }

  Future<String?> updateUserLockStatus(String uid, bool lockStatus) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isLocked': lockStatus,
      });
      return null;
    } catch (e) {
      debugPrint("Error updating lock status: $e");
      return "Không thể cập nhật trạng thái khóa: $e";
    }
  }

  Future<String?> updateUserRole(String uid, String newRole) async {
    try {
      await _db.collection('users').doc(uid).update({
        'role': newRole,
      });
      return null;
    } catch (e) {
      debugPrint("Error updating user role: $e");
      return "Không thể cập nhật vai trò: $e";
    }
  }

  // =================================================================
  // CÁC HÀM CƠ BẢN KHÁC
  // =================================================================
  
  // HÀM LOGOUT ĐÃ ĐƯỢC SỬA: ĐĂNG XUẤT CẢ GOOGLE VÀ FIREBASE
  Future<void> logout() async {
    // Thêm logic xóa/unlik token khi đăng xuất
    try {
      await FcmTokenService().unlinkAndDeleteToken();
    } catch (e) { 
        debugPrint('Lỗi xóa token khi logout: $e');
    }
    
    // Đăng xuất khỏi Google để xóa session và buộc chọn lại tài khoản 
    try {
      await _googleSignIn.signOut(); 
    } catch (e) {
      debugPrint('Lỗi Google Sign-Out khi logout: $e');
    }

    await _auth.signOut();
    Fluttertoast.showToast(msg: 'Đăng xuất thành công!');
  }

  // Streams: (Getter này chính xác và là thứ main.dart đang tìm kiếm)
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // User hiện tại
  User? get currentUser => _auth.currentUser;
}
