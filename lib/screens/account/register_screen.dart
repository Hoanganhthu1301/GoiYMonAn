import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

import 'login_screen.dart';
import '../onboarding/onboarding_flow.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      // Đăng ký user mới
      final User? user = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _displayNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        // Tạo hoặc cập nhật document Firestore cho user vừa đăng ký
        await ProfileService().ensureUserDoc(user);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thất bại. Email có thể đã tồn tại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF4CAF50);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Ký'),
        backgroundColor: primaryGreen,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF3F9F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Vui lòng nhập tên của bạn'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Vui lòng nhập email' : null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Mật khẩu'),
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mật khẩu cần ít nhất 6 ký tự'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Đăng Ký'),
                            ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        child: const Text('Đã có tài khoản? Đăng nhập ngay'),
                        style: TextButton.styleFrom(foregroundColor: primaryGreen),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
