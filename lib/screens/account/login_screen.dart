// lib/screens/account/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import 'register_screen.dart';
import '../dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hàm xử lý chung cho mọi loại Đăng nhập (Email/GitHub/Ẩn danh)
  Future<void> _handleSuccessfulLogin(User user) async {
    // 1. Đảm bảo users/{uid} tồn tại và cập nhật profile
    await ProfileService().ensureUserDoc(user);
    
    if (!mounted) return;

    // 2. Lấy vai trò 
    final role = await _authService.getCurrentUserRole();

    if (!mounted) return;

    // 3. Chuyển hướng dựa trên vai trò
    Widget nextScreen = const DashboardScreen();
    if (role == 'admin') {
      // Giữ Dashboard làm màn hình mặc định sau khi đăng nhập (thay vì UserManagementScreen)
      nextScreen = const DashboardScreen(); 
    }
    
    // 4. Chuyển hướng cuối cùng
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }


  // Logic Đăng nhập bằng Email/Password
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final User? user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        await _handleSuccessfulLogin(user);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thất bại. Kiểm tra email/mật khẩu.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
  
  // Logic Đăng nhập bằng Google
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    
    final User? user = await _authService.signInWithGoogle();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      await _handleSuccessfulLogin(user);
    }
  }


  // Logic Đăng nhập bằng GitHub
  Future<void> _loginWithGitHub() async {
    setState(() => _isLoading = true);
    
    final User? user = await _authService.signInWithGitHub();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      await _handleSuccessfulLogin(user);
    }
  }

  // Logic Đăng nhập Ẩn danh
  Future<void> _loginAnonymously() async {
    setState(() => _isLoading = true);
    
    final User? user = await _authService.signInAnonymously();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      await _handleSuccessfulLogin(user);
    }
  }

  // Thay thế _showForgotPasswordDialog bằng phiên bản an toàn
  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKeyReset = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool sending = false;
        bool success = false;
        String? errorMsg;

        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: success
                  ? const Text('Đã gửi')
                  : const Text('Đặt lại mật khẩu'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!success) ...[
                      const Text('Nhập email liên kết với tài khoản của bạn.'),
                      const SizedBox(height: 12),
                      Form(
                        key: formKeyReset,
                        child: TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Nhập email';
                            }
                            final re = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                            if (!re.hasMatch(v.trim())) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMsg!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ] else ...[
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chúng tôi đã gửi hướng dẫn. Vui lòng kiểm tra hộp thư.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!success)
                  TextButton(
                    onPressed: sending
                        ? null
                        : () {
                            try {
                              Navigator.of(dialogCtx).pop();
                            } catch (_) {}
                          },
                    child: const Text('Hủy'),
                  ),
                if (!success)
                  ElevatedButton(
                    onPressed: sending
                        ? null
                        : () async {
                              if (!(formKeyReset.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              setState(() => sending = true);
                              final email = emailController.text.trim();

                              String? result;
                              try {
                                result = await _authService.sendPasswordReset(
                                  email,
                                );
                              } catch (e, st) {
                                debugPrint('sendPasswordReset threw: $e\n$st');
                                result = e.toString();
                              }

                              // After async: update dialog UI (we are still inside dialog builder's setState)
                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                sending = false;
                                if (result == null) {
                                  success = true;
                                  errorMsg = null;
                                  // copy into main login email field so user still sees it
                                  _emailController.text = email;
                                } else {
                                  errorMsg = 'Lỗi: $result';
                                }
                              });
                            },
                    child: sending
                        ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                        : const Text('Gửi'),
                  ),
                if (success)
                  TextButton(
                    onPressed: () {
                      try {
                        Navigator.of(dialogCtx).pop();
                      } catch (_) {}
                    },
                    child: const Text('Đóng'),
                  ),
              ],
            );
          },
        );
      },
    );

    // Dispose controller after dialog closed
    try {
      emailController.dispose();
    } catch (_) {}
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng Nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trường Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Nhập email';
                  }
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // Trường Mật khẩu
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Nhập mật khẩu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Nút Quên mật khẩu
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Quên mật khẩu?'),
                ),
              ),

              const SizedBox(height: 12),
              // Nút Đăng nhập Email/Pass
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Đăng Nhập'),
                    ),
              
              const SizedBox(height: 16),
              
              // Nút Đăng nhập Google
              ElevatedButton.icon(
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Đăng nhập với Google'),
                onPressed: _loginWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Màu đỏ nổi bật
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              
              const SizedBox(height: 8),

              // Nút Đăng nhập bằng GitHub
              ElevatedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Đăng nhập với GitHub'),
                onPressed: _loginWithGitHub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              // Nút Đăng nhập Ẩn danh
              TextButton(
                onPressed: _loginAnonymously,
                child: const Text('Đăng nhập Ẩn danh'),
              ),

              // Nút Đăng ký
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
