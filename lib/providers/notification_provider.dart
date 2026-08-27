import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref("smartdrip/notifications");

  List<NotificationModel> _notifications = [];

  bool _isLoading = false;

  String? _errorMessage;

  StreamSubscription<DatabaseEvent>? _subscription;

  // ============================================================
  // GETTERS
  // ============================================================

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  bool get hasUnread => unreadCount > 0;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  NotificationProvider() {
    _listenToFirebase();
  }

  // ============================================================
  // REAL-TIME FIREBASE LISTENER
  // ============================================================

  void _listenToFirebase() {
    _subscription = _ref.onValue.listen(
      (event) {
        try {
          final data = event.snapshot.value;

          if (data == null) {
            _notifications = [];
            _errorMessage = null;

            notifyListeners();
            return;
          }

          if (data is! Map) {
            _notifications = [];

            _errorMessage = "Invalid notification data.";

            notifyListeners();
            return;
          }

          final List<NotificationModel> loaded = [];

          data.forEach((key, value) {
            if (value is Map) {
              final json = Map<String, dynamic>.from(value);

              loaded.add(
                NotificationModel.fromJson(
                  json,
                  firebaseId: key.toString(),
                ),
              );
            }
          });

          // Newest first
          loaded.sort(
            (a, b) => b.timestamp.compareTo(a.timestamp),
          );

          _notifications = loaded;

          _errorMessage = null;

          notifyListeners();
        } catch (e) {
          _errorMessage = e.toString();

          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = error.toString();

        notifyListeners();
      },
    );
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshNotifications() async {
    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      final snapshot = await _ref.get();

      final data = snapshot.value;

      if (data == null) {
        _notifications = [];
      } else if (data is Map) {
        final List<NotificationModel> loaded = [];

        data.forEach((key, value) {
          if (value is Map) {
            final json = Map<String, dynamic>.from(value);

            loaded.add(
              NotificationModel.fromJson(
                json,
                firebaseId: key.toString(),
              ),
            );
          }
        });

        loaded.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );

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

  // ============================================================
  // MARK ONE AS READ
  // ============================================================

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

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> markAllRead() async {
    try {
      final Map<String, dynamic> updates = {};

      for (final notification in _notifications) {
        if (!notification.isRead) {
          updates[
            "${notification.id}/isRead"
          ] = true;
        }
      }

      if (updates.isNotEmpty) {
        await _ref.update(updates);
      }
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // ============================================================
  // ADD NOTIFICATION
  // ============================================================

  Future<void> addNotification(
    NotificationModel notification,
  ) async {
    try {
      await _ref.child(notification.id).set(
        notification.toJson(),
      );
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // ============================================================
  // DELETE ONE
  // ============================================================

  Future<void> deleteNotification(String id) async {
    try {
      await _ref.child(id).remove();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  Future<void> clearAll() async {
    try {
      await _ref.remove();
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}