import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'providers/app_provider.dart';
import 'routes/app_routes.dart';

/// Root application widget for SmartDrip
class SmartDripApp extends StatelessWidget {
  const SmartDripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return MaterialApp(
          title: 'SmartDrip',
          debugShowCheckedModeBanner: false,

          // Theme
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          themeAnimationDuration: Duration.zero,

          // Navigation
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generateRoute,

          // ================= RESPONSIVE / WEB-DESKTOP LOCK =================
          // Keeps the app locked to a mobile-sized width and centered when
          // running on wider viewports (Flutter Web / desktop Chrome).
          // On an actual mobile device (width <= 480), this has no visible
          // effect since the constraint is never reached.
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: appProvider.isDarkMode
                  ? const Color(0xff0f0f0f)
                  : const Color(0xffE8ECE6),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: MediaQuery(
                    // Recompute size so layout code relying on
                    // MediaQuery.size (if any) matches the constrained width.
                    data: MediaQuery.of(context).copyWith(
                      size: Size(
                        MediaQuery.of(context).size.width > 480
                            ? 480
                            : MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height,
                      ),
                    ),
                    child: child!,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
