import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import 'notification_service.dart';

/// Listens for new alert records written to /smartdrip/alerts
/// (populated by the Cloud Function — see functions/index.js)
/// and shows a local notification while the app is in the foreground.
///
/// Background/closed-app notifications are handled separately by FCM,
/// sent directly from the same Cloud Function.
class AlertService {
  static DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref("smartdrip/alerts");

  static StreamSubscription<DatabaseEvent>? _subscription;

  static void startListening() {
    // Avoid attaching duplicate listeners if called more than once
    _subscription?.cancel();

    _subscription = _ref.onChildAdded.listen((event) {
      final raw = event.snapshot.value;

      if (raw == null || raw is! Map) return;

      // Firebase returns Map<Object?, Object?> (LinkedMap), so convert
      // safely rather than casting directly to Map<String, dynamic>.
      final data = Map<String, dynamic>.from(raw as Map);

      // The Cloud Function writes a specific title per alert type
      // (Pump ON/OFF, Very Dry, Offline, Reconnected, High Temp, Low Water).
      final title = data["title"]?.toString() ?? "SmartDrip Alert";
      final message = data["message"]?.toString() ?? "Alert";

      NotificationService.showNotification(title, message);
    }, onError: (error) {
      debugPrint("AlertService listen error: $error");
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}