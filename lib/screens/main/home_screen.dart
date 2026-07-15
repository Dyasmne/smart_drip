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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /// ================= APP BAR =================
          SliverAppBar(
            expandedHeight: 104, // was 130
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      _actionCard(
                        context,
                        Icons.show_chart,
                        "Monitor",
                        AppRoutes.monitoring,
                      ),
                      _actionCard(
                        context,
                        Icons.tune,
                        "Control",
                        AppRoutes.control,
                      ),
                      _actionCard(
                        context,
                        Icons.history,
                        "History",
                        AppRoutes.history,
                      ),
                      _actionCard(
                        context,
                        Icons.notifications,
                        "Alerts",
                        AppRoutes.notifications,
                      ),
                      _actionCard(
                        context,
                        Icons.settings,
                        "Settings",
                        AppRoutes.settings,
                      ),
                      _actionCard(
                        context,
                        Icons.refresh,
                        "Refresh",
                        null,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionCard(
    BuildContext context,
    IconData icon,
    String label,
    String? route,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffF8FAF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
