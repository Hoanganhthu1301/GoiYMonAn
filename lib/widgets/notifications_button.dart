import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationsButton extends StatefulWidget {
  final Color color;
  const NotificationsButton({super.key, this.color = Colors.black}); 

  @override
  State<NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<NotificationsButton> {
  final _svc = NotificationService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final c = await _svc.unreadCountOnce();
    if (!mounted) return;
    setState(() => _unread = c);
  }

  @override
Widget build(BuildContext context) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        tooltip: 'Thông báo',
        icon: Icon(Icons.notifications_none, color: widget.color), // <-- dùng màu truyền vào
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
          if (!mounted) return;
          await _reload(); // cập nhật badge khi quay về
        },
      ),
      if (_unread > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              _unread > 99 ? '99+' : '$_unread',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  );
}
}