import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app.dart';

import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/irrigation_provider.dart';
import 'providers/notification_provider.dart';

import 'core/services/notification_service.dart';

/// ================= FIREBASE INIT =================
Future<void> _ensureFirebaseInitialized() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _ensureFirebaseInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Local notifications only — no FCM/Cloud Function needed.
  // SensorProvider fires alerts directly when it detects state changes
  // (pump on/off, very dry soil, high temp, offline, etc.) while the
  // app is running.
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint("Notification initialization failed: $e");
  }

  runApp(const SmartDripRoot());
}

/// ================= ROOT APP =================
class SmartDripRoot extends StatelessWidget {
  const SmartDripRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SensorProvider()),
        ChangeNotifierProvider(create: (_) => IrrigationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const SmartDripApp(),
    );
  }
}