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

  Future<void> _handleSuccessfulLogin(User user) async {
    await ProfileService().ensureUserDoc(user);

    if (!mounted) return;
    final role = await _authService.getCurrentUserRole();
    if (!mounted) return;

    Widget nextScreen = const DashboardScreen();
    if (role == 'admin') {
      nextScreen = const DashboardScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thất bại. Kiểm tra email/mật khẩu.')),
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final User? user = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (user != null) await _handleSuccessfulLogin(user);
  }

  Future<void> _loginWithGitHub() async {
    setState(() => _isLoading = true);
    final User? user = await _authService.signInWithGitHub();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (user != null) await _handleSuccessfulLogin(user);
  }

  Future<void> _loginAnonymously() async {
    setState(() => _isLoading = true);
    final User? user = await _authService.signInAnonymously();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (user != null) await _handleSuccessfulLogin(user);
  }

  InputDecoration themedInput(String label, ThemeData theme) {
    final themeInput = theme.inputDecorationTheme;
    return InputDecoration(
      labelText: label,
      filled: themeInput.filled,
      fillColor: themeInput.fillColor,
      contentPadding: themeInput.contentPadding,
      border: themeInput.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.08, // 8% margin 2 bên
            vertical: screenHeight * 0.05,  // 5% top/bottom padding
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              minHeight: screenHeight * 0.7, // Chiều cao tối thiểu 70% màn hình
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              SizedBox(
                  height: screenHeight * 0.3, // vẫn giữ khung cũ, không kéo khoảng cách
                  child: Center(
                    child: Transform.scale(
                      scale: 1.5, // tăng logo 50% so với khung
                      child: Image.asset(
                        'assets/images/suplo_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),

                // Form login
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: themedInput('Email', theme),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Nhập email';
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      TextFormField(
                        controller: _passwordController,
                        decoration: themedInput('Mật khẩu', theme),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {}, // có thể thêm _showForgotPasswordDialog
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, screenHeight * 0.06),
                              ),
                              child: const Text('Đăng Nhập'),
                            ),
                      SizedBox(height: screenHeight * 0.015),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Đăng nhập với Google'),
                        onPressed: _loginWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, screenHeight * 0.06),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.code),
                        label: const Text('Đăng nhập với GitHub'),
                        onPressed: _loginWithGitHub,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, screenHeight * 0.06),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      TextButton(
                        onPressed: _loginAnonymously,
                        child: const Text('Đăng nhập Ẩn danh'),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text('Chưa có tài khoản? Đăng ký'),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
