import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_config.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _logoAsset = 'assets/images/smartdrip.png';

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Simple pulsing dot loop, similar to a minimal branding splash.
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _start();
  }

  Future<void> _start() async {
    _controller.forward();

    final results = await Future.wait([
      Future.delayed(Duration(seconds: AppConfig.splashDuration)),
      _resolveInitialRoute(),
    ]);

    if (!mounted) return;

    final route = results[1] as String;
    Navigator.pushReplacementNamed(context, route);
  }

  Future<String> _resolveInitialRoute() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null ? AppRoutes.home : AppRoutes.login;
    } catch (e, st) {
      debugPrint('Splash: auth check failed, defaulting to login: $e\n$st');
      if (mounted) setState(() {});
      return AppRoutes.login;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC8E6C9), // light green
              Color(0xFFE8F5E9), // almost-white green
              Color(0xFFFFFFFF), // white
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      _logoAsset,
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),
                    _PulsingDot(controller: _dotController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal single-dot loading indicator (fade in/out loop),
/// matching a clean branding-screen style instead of a spinner.
class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
