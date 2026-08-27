import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import 'notification_service.dart';

/// Listens for new notifications created by the ESP32
/// at:
///
/// /smartdrip/notifications
///
/// No FCM.
/// No Cloud Functions.
/// No device tokens.
///
/// Firebase Realtime Database is only used as the
/// communication/storage layer.
class AlertService {
  AlertService._();

  static final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('smartdrip/notifications');

  static StreamSubscription<DatabaseEvent>? _subscription;

  // Prevent showing the existing notifications again
  // when the listener starts.
 

  // ============================================================
  // START LISTENING
  // ============================================================

  static Future<void> startListening() async {
    // Prevent duplicate listeners
    await stopListening();

    // Initialize local notification service first
    await NotificationService.init();

    _subscription = _ref.onChildAdded.listen(
      (event) {
        try {
          final value = event.snapshot.value;

          if (value == null || value is! Map) {
            return;
          }

          final data = Map<String, dynamic>.from(value);

          final String title =
              data['title']?.toString() ?? 'SmartDrip Alert';

          final String message =
              data['message']?.toString() ?? 'SmartDrip needs your attention.';

          // ------------------------------------------------------
          // IMPORTANT
          // ------------------------------------------------------
          //
          // onChildAdded can fire for existing Firebase records
          // when the app starts.
          //
          // We only want to show a local notification for records
          // that are newly created after the listener starts.
          //
          // The timestamp comes from the ESP32.
          //

          final timestamp = data['timestamp'];

          if (timestamp is num) {
            final createdAt =
                DateTime.fromMillisecondsSinceEpoch(
              timestamp.toInt(),
            );

            final age =
                DateTime.now().difference(createdAt).inSeconds;

            // Ignore old notifications
            if (age > 15) {
              return;
            }
          }

          // ------------------------------------------------------
          // SHOW LOCAL NOTIFICATION
          // ------------------------------------------------------

          NotificationService.showNotification(
            title,
            message,
          );

          debugPrint(
            'SmartDrip Alert: $title - $message',
          );
        } catch (e) {
          debugPrint(
            'AlertService processing error: $e',
          );
        }
      },
      onError: (error) {
        debugPrint(
          'AlertService Firebase error: $error',
        );
      },
    );

    debugPrint(
      'SmartDrip AlertService started.',
    );
  }

  // ============================================================
  // STOP LISTENING
  // ============================================================

  static Future<void> stopListening() async {
    await _subscription?.cancel();

    _subscription = null;

    debugPrint(
      'SmartDrip AlertService stopped.',
    );
  }
}