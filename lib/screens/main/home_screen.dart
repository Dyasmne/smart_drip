import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/soil_zones.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../providers/irrigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/helpers.dart';
import '../../routes/app_routes.dart';
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

// ---------------------------------------------------------------------------
// Shared zone helpers (colors come from soil_zones.dart)
// ---------------------------------------------------------------------------
typedef _Zone = SoilZone;

final Color _dryColor = SoilZones.color(SoilZone.dry);
final Color _idealColor = SoilZones.color(SoilZone.ideal);
final Color _wetColor = SoilZones.color(SoilZone.wet);
final Color _offlineColor = SoilZones.color(SoilZone.offline);

double? _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v == null) return null;
  return double.tryParse(v.toString());
}

String _fmtDuration(Duration d) {
  final mins = d.inMinutes;
  if (mins < 1) return "0 min";
  if (mins < 60) return "$mins min";
  final h = d.inHours;
  final m = mins % 60;
  return "${h}h ${m.toString().padLeft(2, '0')}m";
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

  /// How fresh the last reading must be to call the sensor "live".
  static const _liveThreshold = Duration(minutes: 2);

  /// Pump flow rate in liters per minute. Leave null to hide "Water used".
  static const double? _flowRateLpm = null;

  final Stream<DatabaseEvent> _settingsStream =
      FirebaseDatabase.instance.ref('smartdrip/settings').onValue;

  bool _isSensorLive(DateTime? lastUpdated) {
    if (lastUpdated == null) return false;
    return DateTime.now().difference(lastUpdated) < _liveThreshold;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _settingsStream,
        builder: (context, settingsSnap) {
          double low = SoilZones.defaultLow;
          double high = SoilZones.defaultHigh;
          final raw = settingsSnap.data?.snapshot.value;
          if (raw is Map) {
            low = _asDouble(raw['lowThreshold']) ?? low;
            high = _asDouble(raw['highThreshold']) ?? high;
          }

          return Consumer2<SensorProvider, IrrigationProvider>(
            builder: (context, sensor, irrigation, _) {
              final double moisture = sensor.moisture.toDouble();
              final DateTime? lastUpdated = sensor.lastUpdated;
              final bool live = _isSensorLive(lastUpdated);
              final bool isAuto = irrigation.modeLabel.toLowerCase() == "auto";

              final _Zone zone =
                  SoilZones.of(moisture, low: low, high: high, live: live);

              return CustomScrollView(
                slivers: [
                  _buildAppBar(zone),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ---------- STATUS STRIP (live / offline shown inside) ----------
                        _StatusStrip(
                          moisture: moisture,
                          zone: zone,
                          live: live,
                          pumpOn: irrigation.isPumpOn,
                          isAuto: isAuto,
                          isDark: isDark,
                          lastUpdated: lastUpdated,
                        ),

                        const SizedBox(height: 22),

                        // ---------- TODAY ----------
                        _SectionLabel("Today", isDark),
                        _TodaySummary(
                          isPumpOn: irrigation.isPumpOn,
                          flowRateLpm: _flowRateLpm,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 22),

                        // ---------- QUICK ACTIONS ----------
                        _SectionLabel("Quick Actions", isDark),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.show_chart,
                                label: "Monitor",
                                isDark: isDark,
                                onTap: () => Navigator.pushNamed(
                                    context, AppRoutes.monitoring),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.wifi,
                                label: "Status",
                                isDark: isDark,
                                onTap: () => SystemStatusDialog.show(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.refresh,
                                label: "Refresh",
                                isDark: isDark,
                                onTap: () => _handleRefresh(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.info_outline,
                                label: "About",
                                isDark: isDark,
                                onTap: () =>
                                    AboutSmartDripDialog.show(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // ---------- RECENT ACTIVITY ----------
                        _RecentActivity(isDark: isDark),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ================= APP BAR (color follows soil state) =================
  Widget _buildAppBar(_Zone zone) {
    final gradient = SoilZones.gradient(zone);
    return SliverAppBar(
      expandedHeight: 88,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: gradient.first,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
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
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              "SmartDrip",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<NotificationProvider>(
                    builder: (context, notif, _) {
                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.notifications),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications,
                                color: Colors.white, size: 23),
                            if (notif.hasUnread)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: CircleAvatar(
                                  radius: 7,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    "${notif.unreadCount}",
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.white),
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
    );
  }

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
}

// ===========================================================================
// STATUS STRIP  (moisture + zone + ESP32 live/offline + pump)
// ===========================================================================
class _StatusStrip extends StatelessWidget {
  final double moisture;
  final _Zone zone;
  final bool live;
  final bool pumpOn;
  final bool isAuto;
  final bool isDark;
  final DateTime? lastUpdated;

  const _StatusStrip({
    required this.moisture,
    required this.zone,
    required this.live,
    required this.pumpOn,
    required this.isAuto,
    required this.isDark,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SoilZones.color(zone);
    final grey = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final pumpText = !live
        ? "Pump unknown"
        : pumpOn
            ? "Pump ON"
            : "Pump OFF";

    final seen = lastUpdated == null
        ? "Waiting for the first reading"
        : "Last seen ${AppFormatters.formatRelativeTime(lastUpdated!)} • "
            "${AppFormatters.formatTime(lastUpdated!)}";

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            "${moisture.clamp(0, 100).toStringAsFixed(0)}%",
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        live
                            ? SoilZones.label(zone).toUpperCase()
                            : "LAST READING",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (live)
                      const _LiveDot()
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 14, color: _offlineColor),
                          const SizedBox(width: 4),
                          Text(
                            "Offline",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _offlineColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "$pumpText · ${isAuto ? 'Auto' : 'Manual'}",
                  style: TextStyle(fontSize: 12.5, color: grey),
                ),
                if (!live) ...[
                  const SizedBox(height: 2),
                  Text(
                    seen,
                    style: TextStyle(fontSize: 11.5, color: grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _idealColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          "Live",
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _idealColor,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// TODAY SUMMARY (from smartdrip/irrigation_logs)
// ===========================================================================
class _TodaySummary extends StatefulWidget {
  final bool isPumpOn;
  final double? flowRateLpm;
  final bool isDark;

  const _TodaySummary({
    required this.isPumpOn,
    required this.flowRateLpm,
    required this.isDark,
  });

  @override
  State<_TodaySummary> createState() => _TodaySummaryState();
}

class _TodaySummaryState extends State<_TodaySummary> {
  final Stream<DatabaseEvent> _logStream = FirebaseDatabase.instance
      .ref('smartdrip/irrigation_logs')
      .limitToLast(100)
      .onValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _logStream,
      builder: (context, snap) {
        int wateringsToday = 0;
        Duration runtime = Duration.zero;
        DateTime? lastWatered;

        final raw = snap.data?.snapshot.value;
        if (raw is Map) {
          final events = <MapEntry<DateTime, bool>>[];
          for (final v in raw.values) {
            if (v is! Map) continue;
            final action = (v['action'] ?? '').toString().toUpperCase().trim();
            final tsRaw = v['timestamp'];
            final ms = tsRaw is num ? tsRaw.toInt() : int.tryParse('$tsRaw');
            if (ms == null) continue;
            final isOn = action.endsWith('ON');
            final isOff = action.endsWith('OFF');
            if (!isOn && !isOff) continue;
            events.add(MapEntry(DateTime.fromMillisecondsSinceEpoch(ms), isOn));
          }
          events.sort((a, b) => a.key.compareTo(b.key));

          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);

          DateTime? onAt;
          for (final e in events) {
            if (e.value) lastWatered = e.key;
            if (e.key.isBefore(todayStart)) continue;

            if (e.value) {
              wateringsToday++;
              onAt ??= e.key;
            } else if (onAt != null) {
              runtime += e.key.difference(onAt);
              onAt = null;
            }
          }
          if (onAt != null && widget.isPumpOn) {
            runtime += now.difference(onAt);
          }
        }

        final tiles = <_StatTile>[
          _StatTile(
            icon: Icons.opacity,
            value: "$wateringsToday",
            label: wateringsToday == 1 ? "Watering" : "Waterings",
            color: _wetColor,
            isDark: widget.isDark,
          ),
          _StatTile(
            icon: Icons.timer_outlined,
            value: _fmtDuration(runtime),
            label: "Pump runtime",
            color: _dryColor,
            isDark: widget.isDark,
          ),
          _StatTile(
            icon: Icons.history_toggle_off,
            value: lastWatered == null
                ? "—"
                : AppFormatters.formatRelativeTime(lastWatered),
            label: "Last watered",
            color: _idealColor,
            isDark: widget.isDark,
          ),
          if (widget.flowRateLpm != null)
            _StatTile(
              icon: Icons.water,
              value:
                  "${(runtime.inSeconds / 60 * widget.flowRateLpm!).toStringAsFixed(1)} L",
              label: "Water used",
              color: Colors.teal,
              isDark: widget.isDark,
            ),
        ];

        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// RECENT ACTIVITY (last 3 pump events from smartdrip/irrigation_logs)
// ===========================================================================
class _RecentActivity extends StatefulWidget {
  final bool isDark;
  const _RecentActivity({required this.isDark});

  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  final Stream<DatabaseEvent> _stream = FirebaseDatabase.instance
      .ref('smartdrip/irrigation_logs')
      .limitToLast(20)
      .onValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;
    final grey = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return StreamBuilder<DatabaseEvent>(
      stream: _stream,
      builder: (context, snap) {
        final raw = snap.data?.snapshot.value;
        if (raw is! Map) return const SizedBox.shrink();

        final items = <_Activity>[];
        for (final v in raw.values) {
          if (v is! Map) continue;
          final action = (v['action'] ?? '').toString().toUpperCase().trim();
          final tsRaw = v['timestamp'];
          final ms = tsRaw is num ? tsRaw.toInt() : int.tryParse('$tsRaw');
          if (ms == null) continue;
          final time = DateTime.fromMillisecondsSinceEpoch(ms);
          if (time.year < 2020) continue;
          final isOff = action.endsWith('OFF');
          final isOn = action.endsWith('ON');
          if (!isOn && !isOff) continue;
          items.add(_Activity(
            time: time,
            isOn: isOn,
            isAuto: action.contains('AUTO'),
            soil: _asDouble(v['soil']),
          ));
        }
        if (items.isEmpty) return const SizedBox.shrink();

        items.sort((a, b) => b.time.compareTo(a.time));
        final recent = items.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel("Recent Activity", isDark),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.22 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 60,
                        endIndent: 14,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    _activityRow(recent[i], grey),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _activityRow(_Activity a, Color grey) {
    final color = a.isOn ? _wetColor : _offlineColor;
    final mode = a.isAuto ? "Auto" : "Manual";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(widget.isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              a.isOn ? Icons.water_drop : Icons.power_settings_new,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.isOn ? "Pump turned ON" : "Pump turned OFF",
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  a.soil == null
                      ? mode
                      : "$mode · soil ${a.soil!.toStringAsFixed(0)}%",
                  style: TextStyle(fontSize: 11.5, color: grey),
                ),
              ],
            ),
          ),
          Text(
            AppFormatters.formatRelativeTime(a.time),
            style: TextStyle(fontSize: 11.5, color: grey),
          ),
        ],
      ),
    );
  }
}

class _Activity {
  final DateTime time;
  final bool isOn;
  final bool isAuto;
  final double? soil;
  const _Activity({
    required this.time,
    required this.isOn,
    required this.isAuto,
    required this.soil,
  });
}

// ===========================================================================
// SMALL SHARED WIDGETS
// ===========================================================================
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}