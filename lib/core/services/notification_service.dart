import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

/// Handles both:
/// 1. Local notifications (shown while app is in foreground)
/// 2. Firebase Cloud Messaging / FCM (shown when app is backgrounded or closed,
///    triggered by a Cloud Function watching the RTDB — see functions/index.js)
///
/// Fully static so it can be called directly as NotificationService.xxx(...)
/// from anywhere (e.g. AlertService) without needing an instance.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const String _channelId = 'low_soil_alerts';
  static const String _channelName = 'Low Soil Moisture Alerts';
  static const String _channelDesc =
      'Notifications when soil moisture drops below the safe threshold';

  static bool _initialized = false;

  // ================= INIT =================

  static Future<void> init() async {
    if (_initialized) return;

    // ---------- Local notifications setup ----------
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    // Android 13+ needs explicit runtime permission
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // ---------- FCM setup ----------
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Save/refresh the device token in RTDB so the Cloud Function
    // knows where to send the push when soil moisture is low.
    await _saveTokenToDatabase();
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

    // Foreground FCM messages: Firebase does NOT auto-show a system
    // notification while the app is open, so show it manually here.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          title: notification.title ?? 'Smart Drip Alert',
          body: notification.body ?? '',
        );
      }
    });

    _initialized = true;
  }

  static Future<void> _saveTokenToDatabase([String? token]) async {
    try {
      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null) return;

      await FirebaseDatabase.instance
          .ref('smartdrip/deviceTokens/$fcmToken')
          .set(true);

      debugPrint('FCM token saved: $fcmToken');
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  // ================= LOCAL NOTIFICATION (foreground alert) =================

  static Future<void> showNotification(String title, String body) async {
    await showLocalNotification(title: title, body: body);
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xff1B5E20),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Convenience method specifically for the low-moisture alert.
  static Future<void> showLowMoistureAlert(double moisture) async {
    await showLocalNotification(
      title: '⚠️ Low Soil Moisture',
      body:
          'Soil moisture is at ${moisture.toStringAsFixed(1)}%. Your plants may need watering soon.',
    );
  }
}