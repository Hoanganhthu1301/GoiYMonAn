// lib/screens/account/user_management_screen.dart

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final int pageSize = 10; // số người mỗi trang
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Người dùng'),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: AuthService().getUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có người dùng nào.'));
          }

          final users = snapshot.data!;
          final totalPages = (users.length / pageSize).ceil();
          final start = currentPage * pageSize;
          final end = (start + pageSize > users.length) ? users.length : start + pageSize;
          final currentUsers = users.sublist(start, end);
          final currentUserUid = AuthService().currentUser?.uid;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: currentUsers.length,
                  itemBuilder: (context, index) {
                    final user = currentUsers[index];
                    final isCurrentUser = user.uid == currentUserUid;
                    final isLocked = user.isLocked;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLocked
                              ? theme.colorScheme.error
                              : _getRoleColor(user.role, theme),
                          child: Text(user.role[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(user.displayName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${user.email}\nVai trò: ${user.role} | Trạng thái: ${isLocked ? 'ĐÃ KHÓA' : 'HOẠT ĐỘNG'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: isLocked
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary),
                        ),
                        isThreeLine: true,
                        trailing: isCurrentUser
                            ? Chip(
                                label: Text('Bạn (Admin)',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                              )
                            : _LockToggleButton(user: user, theme: theme),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: currentPage > 0
                            ? () => setState(() => currentPage--)
                            : null,
                        child: const Text('Trước'),
                      ),
                      Text('Trang ${currentPage + 1} / $totalPages'),
                      TextButton(
                        onPressed: currentPage < totalPages - 1
                            ? () => setState(() => currentPage++)
                            : null,
                        child: const Text('Sau'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role, ThemeData theme) {
    switch (role) {
      case 'admin':
        return theme.colorScheme.error;
      case 'editor':
        return theme.colorScheme.secondary;
      default:
        return theme.disabledColor;
    }
  }
}

// --- Nút Khóa/Mở Khóa Tài khoản ---
class _LockToggleButton extends StatelessWidget {
  final AppUser user;
  final ThemeData theme;
  const _LockToggleButton({required this.user, required this.theme});

  @override
  Widget build(BuildContext context) {
    final bool isLocked = user.isLocked;

    return ElevatedButton.icon(
      onPressed: () async {
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isLocked
                ? "Mở khóa ${user.displayName}?"
                : "Khóa tài khoản ${user.displayName}?"),
            content: Text(isLocked
                ? "Tài khoản sẽ được kích hoạt lại và có thể đăng nhập."
                : "Người dùng sẽ không thể đăng nhập."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Hủy")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isLocked ? "Mở Khóa" : "Khóa",
                      style: TextStyle(
                          color: isLocked
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error))),
            ],
          ),
        );

        if (confirm == true) {
          String? errorMessage =
              await AuthService().updateUserLockStatus(user.uid, !isLocked);

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage == null
                  ? 'Đã ${isLocked ? "MỞ KHÓA" : "KHÓA"} ${user.displayName} thành công!'
                  : 'Lỗi: $errorMessage'),
            ),
          );
        }
      },
      icon: Icon(isLocked ? Icons.lock_open : Icons.lock, size: 18),
      label: Text(isLocked ? "Mở Khóa" : "Khóa"),
      style: ElevatedButton.styleFrom(
        backgroundColor: isLocked
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }
}
