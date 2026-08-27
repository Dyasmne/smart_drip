import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../providers/irrigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/helpers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/dashboard/system_status_card.dart';
import '../../widgets/dashboard/system_status_dialog.dart';
import '../../widgets/dashboard/about_smartdrip_dialog.dart';
import 'control_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _tabs = const [
    _DashboardTab(),
    ControlScreen(isTab: true),
    HistoryScreen(isTab: true),
    SettingsScreen(isTab: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "Control"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

/// ================= DASHBOARD TAB =================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /// ================= APP BAR =================
          SliverAppBar(
            expandedHeight: 88, // was 104, trimmed further so it's just right
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF43A047),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Consumer<AuthProvider>(
                            builder: (context, auth, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${AppHelpers.getGreeting()}, ${auth.user?.firstName ?? 'Farmer'} 👋',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12), // was 14
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    "SmartDrip",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19, // was 24
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        /// NOTIFICATIONS
                        Consumer<NotificationProvider>(
                          builder: (context, notif, _) {
                            return GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.notifications),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.notifications,
                                      color: Colors.white, size: 23), // was 28
                                  if (notif.hasUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: CircleAvatar(
                                        radius: 7, // was 8
                                        backgroundColor: Colors.red,
                                        child: Text(
                                          "${notif.unreadCount}",
                                          style: const TextStyle(
                                              fontSize: 9, // was 10
                                              color: Colors.white),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          /// ================= BODY =================
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Consumer2<SensorProvider, IrrigationProvider>(
                  builder: (context, sensor, irrigation, _) {
                    final moisture = sensor.moisture;
                    final lastUpdated = sensor.lastUpdated;

                    return Column(
                      children: [
                        SystemStatusCard(
                          title: "Soil Moisture",
                          value: AppFormatters.formatMoisture(moisture),
                          subtitle: sensor.moistureStatus,
                          icon: Icons.water_drop,
                          color: AppHelpers.getMoistureColor(moisture),
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.monitoring),
                        ),
                        const SizedBox(height: 12),
                        SystemStatusCard(
                          title: "Pump Status",
                          value: irrigation.isPumpOn ? "Running" : "Stopped",
                          subtitle: "Mode: ${irrigation.modeLabel}",
                          icon: Icons.water,
                          color: irrigation.isPumpOn
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        SystemStatusCard(
                          title: "Last Update",
                          value: lastUpdated != null
                              ? AppFormatters.formatRelativeTime(lastUpdated)
                              : "No data",
                          subtitle: lastUpdated != null
                              ? AppFormatters.formatTime(lastUpdated)
                              : "Waiting for ESP32",
                          icon: Icons.access_time,
                          color: AppColors.info,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                /// QUICK ACTIONS
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 20, // was 26
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  // Wrap-based layout: 3 smaller cards per row, responsive
                  // to screen width. WrapAlignment.center automatically
                  // centers the last (incomplete) row.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 12.0;
                      final itemWidth =
                          (constraints.maxWidth - spacing * 2) / 3;

                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: _actionCard(
                              context,
                              Icons.show_chart,
                              "Monitor",
                              isDark: isDark,
                              route: AppRoutes.monitoring,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: _actionCard(
                              context,
                              Icons.wifi,
                              "System Status",
                              isDark: isDark,
                              onTap: () => SystemStatusDialog.show(context),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: _actionCard(
                              context,
                              Icons.notifications,
                              "Alerts",
                              isDark: isDark,
                              route: AppRoutes.notifications,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: _actionCard(
                              context,
                              Icons.refresh,
                              "Refresh",
                              isDark: isDark,
                              onTap: () => _handleRefresh(context),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            height: itemWidth,
                            child: _actionCard(
                              context,
                              Icons.info_outline,
                              "About",
                              isDark: isDark,
                              onTap: () => AboutSmartDripDialog.show(context),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Re-pulls the latest sensor reading from Firebase via
  /// `SensorProvider.refreshData()`.
  ///
  /// IrrigationProvider has no separate refresh call — it stays live via
  /// its own `onValue` stream listener the whole time the app is open, so
  /// its pump/mode state is already always current; there's nothing to
  /// manually re-fetch there.
  static Future<void> _handleRefresh(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text("Refreshing data..."),
          ],
        ),
      ),
    );

    try {
      final sensor = context.read<SensorProvider>();
      await sensor.refreshData();

      messenger.hideCurrentSnackBar();

      if (sensor.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text("Refresh failed: ${sensor.errorMessage}"),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text("Data refreshed"),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text("Refresh failed: $e"),
        ),
      );
    }
  }

  /// [route] navigates via Navigator.pushNamed when tapped.
  /// [onTap] takes priority over [route] when both/either is supplied,
  /// letting a card open a dialog (System Status, About) instead of a route.
  /// Passing neither keeps the existing no-op behavior (e.g. "Refresh").
  static Widget _actionCard(
    BuildContext context,
    IconData icon,
    String label, {
    required bool isDark,
    String? route,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.scaffoldBackgroundColor : const Color(0xffF8FAF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}