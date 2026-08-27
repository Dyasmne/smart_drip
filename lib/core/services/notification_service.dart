import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles LOCAL notifications only.
///
/// No Firebase Cloud Messaging (FCM).
/// No Cloud Functions.
/// No FCM device tokens.
///
/// Firebase Realtime Database is handled separately by
/// AlertService and NotificationProvider.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'smartdrip_alerts';

  static const String _channelName = 'SmartDrip Alerts';

  static const String _channelDesc =
      'SmartDrip soil moisture and irrigation alerts';

  static bool _initialized = false;

  // ================= INIT =================

  static Future<void> init() async {
    if (_initialized) return;

    // ---------- Android / iOS initialization ----------

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
    );

    // ---------- Android notification permission ----------

    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+
      await androidPlugin?.requestNotificationsPermission();

      // Notification channel
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );

      await androidPlugin?.createNotificationChannel(
        channel,
      );
    }

    _initialized = true;

    debugPrint('SmartDrip Local Notification Service initialized.');
  }

  // ================= SHOW NOTIFICATION =================

  static Future<void> showNotification(
    String title,
    String body,
  ) async {
    await showLocalNotification(
      title: title,
      body: body,
    );
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xff1B5E20),
      icon: '@mipmap/ic_launcher',
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

  // ================= LOW MOISTURE =================

  static Future<void> showLowMoistureAlert(
    double moisture,
  ) async {
    await showLocalNotification(
      title: '⚠️ Low Soil Moisture',
      body:
          'Soil moisture is at ${moisture.toStringAsFixed(1)}%. '
          'Your plants may need watering soon.',
    );
  }

  // ================= CRITICAL MOISTURE =================

  static Future<void> showCriticalMoistureAlert(
    double moisture,
  ) async {
    await showLocalNotification(
      title: '🚨 Critical Soil Moisture',
      body:
          'Soil moisture is critically low at '
          '${moisture.toStringAsFixed(1)}%.',
    );
  }

  // ================= PUMP =================

  static Future<void> showPumpNotification({
    required bool isOn,
    required String mode,
  }) async {
    await showLocalNotification(
      title: isOn ? '💧 Pump ON' : '⛔ Pump OFF',
      body: isOn
          ? 'The irrigation pump has been turned ON in $mode mode.'
          : 'The irrigation pump has been turned OFF in $mode mode.',
    );
  }
}