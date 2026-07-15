import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main/home_screen.dart';
import '../screens/main/monitoring_screen.dart';
import '../screens/main/control_screen.dart';
import '../screens/main/history_screen.dart';
import '../screens/main/notifications_screen.dart';
import '../screens/main/settings_screen.dart';

/// Centralized route definitions for the app
class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String monitoring = '/monitoring';
  static const String control = '/control';
  static const String history = '/history';
  static const String notifications = '/notifications';
  static const String settings = '/settings';

  /// Generate routes based on route name
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), settings);

      case login:
        return _buildRoute(const LoginScreen(), settings);

      case register:
        return _buildRoute(const RegisterScreen(), settings);

      case home:
        return _buildRoute(const HomeScreen(), settings);

      case monitoring:
        return _buildRoute(const MonitoringScreen(), settings);

      case control:
        return _buildRoute(const ControlScreen(), settings);

      case history:
        return _buildRoute(const HistoryScreen(), settings);

      case notifications:
        return _buildRoute(const NotificationsScreen(), settings);

      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen(), settings);

      default:
        // 404 fallback
        return _buildRoute(
          Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  /// Build a page route with smooth slide transition
  static PageRouteBuilder _buildRoute(
      Widget page, RouteSettings routeSettings) {
    return PageRouteBuilder(
      settings: routeSettings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}