import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app.dart';

// Providers
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/irrigation_provider.dart';
import 'providers/notification_provider.dart';

// Local Notification Service
import 'core/services/notification_service.dart';

/// ============================================================
/// FIREBASE INITIALIZATION
/// ============================================================

Future<void> _ensureFirebaseInitialized() async {
  try {
    // Prevent Firebase from being initialized twice
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    // Ignore duplicate Firebase app error
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }
}

/// ============================================================
/// MAIN
/// ============================================================

Future<void> main() async {
  // Required before using plugins
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------
  // Firebase
  // ------------------------------------------------------------

  await _ensureFirebaseInitialized();

  // ------------------------------------------------------------
  // Screen orientation
  // ------------------------------------------------------------

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ------------------------------------------------------------
  // System UI
  // ------------------------------------------------------------

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ------------------------------------------------------------
  // LOCAL NOTIFICATIONS ONLY
  //
  // No Firebase Cloud Messaging
  // No FCM token
  // No Cloud Functions
  // No paid notification service
  //
  // AlertService / SensorProvider can call:
  //
  // NotificationService.showNotification(...)
  //
  // ------------------------------------------------------------

  try {
    await NotificationService.init();

    debugPrint(
      'SmartDrip NotificationService initialized successfully.',
    );
  } catch (e) {
    debugPrint(
      'Notification initialization failed: $e',
    );
  }

  // ------------------------------------------------------------
  // Start application
  // ------------------------------------------------------------

  runApp(
    const SmartDripRoot(),
  );
}

/// ============================================================
/// ROOT APP
/// ============================================================

class SmartDripRoot extends StatelessWidget {
  const SmartDripRoot({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --------------------------------------------------------
        // App Provider
        // --------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => AppProvider(),
        ),

        // --------------------------------------------------------
        // Authentication
        // --------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),

        // --------------------------------------------------------
        // Sensor
        // --------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => SensorProvider(),
        ),

        // --------------------------------------------------------
        // Irrigation
        // --------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => IrrigationProvider(),
        ),

        // --------------------------------------------------------
        // Notifications
        // --------------------------------------------------------

        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
        ),
      ],

      // ----------------------------------------------------------
      // Main SmartDrip App
      // ----------------------------------------------------------

      child: const SmartDripApp(),
    );
  }
}