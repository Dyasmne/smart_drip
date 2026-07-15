import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref("smartdrip/notifications");

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  // =========================
  // GETTERS
  // =========================
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  NotificationProvider() {
    _listenToFirebase();
  }

  // =========================
  // REAL-TIME LISTENER
  // =========================
  void _listenToFirebase() {
    _ref.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data == null) {
        _notifications = [];
        notifyListeners();
        return;
      }

      final Map raw = data as Map;

      final List<NotificationModel> loaded = [];

      raw.forEach((key, value) {
        loaded.add(
          NotificationModel.fromJson(
            Map<String, dynamic>.from(value),
          ),
        );
      });

      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _notifications = loaded;
      notifyListeners();
    });
  }

  // =========================
  // 🔥 REFRESH METHOD (FIX FOR RefreshIndicator)
  // =========================
  Future<void> refreshNotifications() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _ref.get();

      final data = snapshot.value;

      if (data == null) {
        _notifications = [];
      } else {
        final Map raw = data as Map;

        final List<NotificationModel> loaded = [];

        raw.forEach((key, value) {
          loaded.add(
            NotificationModel.fromJson(
              Map<String, dynamic>.from(value),
            ),
          );
        });

        loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _notifications = loaded;
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================
  // MARK AS READ
  // =========================
  Future<void> markAsRead(String id) async {
    try {
      await _ref.child(id).update({
        "isRead": true,
      });
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // =========================
  // MARK ALL AS READ (FIXED)
  // =========================
  Future<void> markAllRead() async {
    try {
      final Map<String, dynamic> updates = {};

      for (final n in _notifications) {
        updates["${n.id}/isRead"] = true;
      }

      await _ref.update(updates);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // =========================
  // ADD NOTIFICATION
  // =========================
  Future<void> addNotification(NotificationModel notification) async {
    try {
      await _ref.child(notification.id).set(notification.toJson());
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // =========================
  // DELETE
  // =========================
  Future<void> deleteNotification(String id) async {
    try {
      await _ref.child(id).remove();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // =========================
  // CLEAR ALL
  // =========================
  Future<void> clearAll() async {
    try {
      await _ref.remove();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}