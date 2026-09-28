import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// ============================================================
/// FCM SERVICE
/// ============================================================
///
/// Handles:
/// - FCM permission
/// - FCM token registration
/// - Saving token per logged-in Firebase user
/// - Token refresh
/// - Foreground notifications
///
/// Firebase Database path:
///
/// smartdrip/users/{uid}/fcmToken
///
/// ============================================================

class FcmService {
  FcmService._();

  static bool _initialized = false;

  // Prevent multiple init() calls from running at the same time.
  static Future<void>? _initializing;

  // ============================================================
  // INIT
  // ============================================================

  static Future<void> init() {
    // Already initialized.
    if (_initialized) {
      return registerCurrentUser();
    }

    // Initialization is already running.
    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _initialize();

    return _initializing!;
  }

  // ============================================================
  // ACTUAL INITIALIZATION
  // ============================================================

  static Future<void> _initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // --------------------------------------------------------
      // Notification permission
      // --------------------------------------------------------

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        'FCM permission status: '
        '${settings.authorizationStatus}',
      );

      // --------------------------------------------------------
      // Register current logged-in user
      // --------------------------------------------------------

      await registerCurrentUser();

      // --------------------------------------------------------
      // Token refresh listener
      // --------------------------------------------------------

      messaging.onTokenRefresh.listen(
        (newToken) async {
          debugPrint('FCM token refreshed.');

          try {
            await _saveToken(newToken);

            debugPrint(
              'New FCM token saved for current user.',
            );
          } catch (e) {
            debugPrint(
              'Failed to save refreshed FCM token: $e',
            );
          }
        },
      );

      // --------------------------------------------------------
      // Foreground messages
      // --------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          debugPrint('========================================');
          debugPrint('FCM MESSAGE RECEIVED');
          debugPrint(
            'Message ID: ${message.messageId}',
          );
          debugPrint(
            'Data: ${message.data}',
          );
          debugPrint('========================================');

          final notification =
              message.notification;

          if (notification == null) {
            debugPrint(
              'FCM message has no notification payload.',
            );
            return;
          }

          final title =
              notification.title ?? 'SmartDrip';

          final body =
              notification.body ??
                  'New notification received.';

          debugPrint(
            'FCM notification title: $title',
          );

          debugPrint(
            'FCM notification body: $body',
          );

          await NotificationService
              .showLocalNotification(
            title: title,
            body: body,
          );
        },
      );

      _initialized = true;

      debugPrint(
        'SmartDrip FcmService initialized successfully.',
      );
    } catch (e) {
      debugPrint(
        'FCM initialization failed: $e',
      );

      rethrow;
    } finally {
      _initializing = null;
    }
  }

  // ============================================================
  // REGISTER CURRENT USER
  // ============================================================

  static Future<void> registerCurrentUser() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'FCM token not saved: no logged-in user.',
        );
        return;
      }

      debugPrint(
        'Registering FCM token for user: ${user.uid}',
      );

      final token =
          await FirebaseMessaging.instance.getToken();

      if (token == null) {
        debugPrint(
          'FCM token is null.',
        );
        return;
      }

      await _saveToken(token);
    } catch (e) {
      debugPrint(
        'Failed to register current user FCM token: $e',
      );
    }
  }

  // ============================================================
  // SAVE TOKEN
  // ============================================================

  static Future<void> _saveToken(
    String token,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint(
        'Cannot save FCM token: no logged-in user.',
      );
      return;
    }

    final uid = user.uid;

    final tokenRef = FirebaseDatabase.instance
        .ref('smartdrip/users/$uid/fcmToken');

    // ----------------------------------------------------------
    // Show exact Firebase path
    // ----------------------------------------------------------

    debugPrint(
      'FCM DATABASE PATH: ${tokenRef.path}',
    );

    // ----------------------------------------------------------
    // Save token
    // ----------------------------------------------------------

    await tokenRef.set(token);

    // ----------------------------------------------------------
    // Verify that Firebase actually saved it
    // ----------------------------------------------------------

    final savedValue = await tokenRef.get();

    debugPrint(
      'FCM SAVED: ${savedValue.exists}',
    );

    if (savedValue.exists) {
      debugPrint(
        'FCM token successfully saved for user: $uid',
      );
    } else {
      debugPrint(
        'WARNING: FCM token write completed '
        'but value was not found.',
      );
    }
  }

  // ============================================================
  // REMOVE TOKEN ON LOGOUT
  // ============================================================

  static Future<void> removeCurrentUserToken() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final uid = user.uid;

      final tokenRef = FirebaseDatabase.instance
          .ref('smartdrip/users/$uid/fcmToken');

      await tokenRef.remove();

      debugPrint(
        'FCM token removed for user: $uid',
      );
    } catch (e) {
      debugPrint(
        'Failed to remove FCM token: $e',
      );
    }
  }
}