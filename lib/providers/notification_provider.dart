import 'package:flutter/material.dart';
import '../services/db_helper.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> loadNotifications(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await DBHelper.instance.getNotifications(userId);
      _unreadCount = await DBHelper.instance.getUnreadNotificationCount(userId);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(int notificationId, int userId) async {
    await DBHelper.instance.markNotificationRead(notificationId);
    await loadNotifications(userId);
  }

  Future<void> markAllRead(int userId) async {
    await DBHelper.instance.markAllNotificationsRead(userId);
    await loadNotifications(userId);
  }

  Future<void> addNotification({
    required int userId,
    required String title,
    required String body,
    String type = 'info',
    int? referenceId,
  }) async {
    await DBHelper.instance.addNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      referenceId: referenceId,
    );
    await loadNotifications(userId);
  }

  void clear() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }
}
