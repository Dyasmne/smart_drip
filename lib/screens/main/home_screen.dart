import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
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
// Soil zones
// ---------------------------------------------------------------------------
enum _Zone { dry, ideal, wet, offline }

const Color _dryColor = Color(0xFFEF6C00);
const Color _idealColor = Color(0xFF2E7D32);
const Color _wetColor = Color(0xFF1976D2);
const Color _offlineColor = Color(0xFF607D8B);

Color _zoneColor(_Zone z) {
  switch (z) {
    case _Zone.dry:
      return _dryColor;
    case _Zone.ideal:
      return _idealColor;
    case _Zone.wet:
      return _wetColor;
    case _Zone.offline:
      return _offlineColor;
  }
}

List<Color> _zoneGradient(_Zone z) {
  switch (z) {
    case _Zone.dry:
      return const [Color(0xFFE65100), Color(0xFFEF6C00), Color(0xFFFB8C00)];
    case _Zone.wet:
      return const [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)];
    case _Zone.offline:
      return const [Color(0xFF37474F), Color(0xFF455A64), Color(0xFF607D8B)];
    case _Zone.ideal:
      return const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)];
  }
}

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

  /// How fresh the last reading must be for the dashboard to call the
  /// sensor "live". Past this the UI switches to its offline look so it
  /// never presents a stale reading as real-time.
  static const _liveThreshold = Duration(minutes: 2);

  /// Fallbacks used only if smartdrip/settings has no thresholds yet.
  static const double _defaultLow = 30;
  static const double _defaultHigh = 70;

  // Created once so the stream isn't re-subscribed on every rebuild.
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
          // ---- thresholds / auto flag from smartdrip/settings ----
          double low = _defaultLow;
          double high = _defaultHigh;
          bool autoIrrigation = false;
          final raw = settingsSnap.data?.snapshot.value;
          if (raw is Map) {
            low = _asDouble(raw['lowThreshold']) ?? low;
            high = _asDouble(raw['highThreshold']) ?? high;
            autoIrrigation = raw['autoIrrigation'] == true;
          }

          return Consumer2<SensorProvider, IrrigationProvider>(
            builder: (context, sensor, irrigation, _) {
              final double moisture = sensor.moisture.toDouble();
              final DateTime? lastUpdated = sensor.lastUpdated;
              final bool live = _isSensorLive(lastUpdated);
              final bool isAuto = irrigation.modeLabel.toLowerCase() == "auto";

              final _Zone zone = !live
                  ? _Zone.offline
                  : moisture < low
                      ? _Zone.dry
                      : moisture > high
                          ? _Zone.wet
                          : _Zone.ideal;

              return CustomScrollView(
                slivers: [
                  _buildAppBar(zone),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (!live) ...[
                          _OfflineBanner(
                            lastUpdated: lastUpdated,
                            onRetry: () => _handleRefresh(context),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ---------- HERO GAUGE ----------
                        _HeroMoistureCard(
                          moisture: moisture,
                          low: low,
                          high: high,
                          zone: zone,
                          live: live,
                          lastUpdated: lastUpdated,
                          isAuto: isAuto,
                          autoIrrigation: autoIrrigation,
                          isDark: isDark,
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.monitoring),
                        ),

                        const SizedBox(height: 14),

                        // ---------- PUMP ----------
                        _PumpCard(
                          isOn: irrigation.isPumpOn,
                          isAuto: isAuto,
                          autoIrrigation: autoIrrigation,
                          low: low,
                          live: live,
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
    return SliverAppBar(
      expandedHeight: 88,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _zoneGradient(zone).first,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _zoneGradient(zone)),
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

  /// Re-pulls the latest sensor reading via SensorProvider.refreshData().
  /// IrrigationProvider stays live through its own onValue listener, so
  /// there's nothing to re-fetch there.
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
// OFFLINE BANNER  (one place that says the device is offline)
// ===========================================================================
class _OfflineBanner extends StatelessWidget {
  final DateTime? lastUpdated;
  final VoidCallback onRetry;

  const _OfflineBanner({required this.lastUpdated, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final sub = lastUpdated == null
        ? "Waiting for the first reading"
        : "Last seen ${AppFormatters.formatRelativeTime(lastUpdated!)} • "
            "${AppFormatters.formatTime(lastUpdated!)}";

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _offlineColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _offlineColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _offlineColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ESP32 is offline",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: _offlineColor),
            child: const Text("Retry",
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// HERO MOISTURE CARD
// ===========================================================================
class _HeroMoistureCard extends StatelessWidget {
  final double moisture;
  final double low;
  final double high;
  final _Zone zone;
  final bool live;
  final DateTime? lastUpdated;
  final bool isAuto;
  final bool autoIrrigation;
  final bool isDark;
  final VoidCallback onTap;

  const _HeroMoistureCard({
    required this.moisture,
    required this.low,
    required this.high,
    required this.zone,
    required this.live,
    required this.lastUpdated,
    required this.isAuto,
    required this.autoIrrigation,
    required this.isDark,
    required this.onTap,
  });

  String get _headline {
    switch (zone) {
      case _Zone.offline:
        return "Last known reading";
      case _Zone.dry:
        return "Soil is dry";
      case _Zone.wet:
        return "Soil is well watered";
      case _Zone.ideal:
        return "Soil moisture is ideal";
    }
  }

  String get _detail {
    switch (zone) {
      case _Zone.offline:
        return lastUpdated == null
            ? "No reading received yet"
            : "Taken ${AppFormatters.formatRelativeTime(lastUpdated!)}";
      case _Zone.dry:
        return (isAuto && autoIrrigation)
            ? "Below ${low.toStringAsFixed(0)}% — watering starts automatically"
            : "Below your ${low.toStringAsFixed(0)}% minimum";
      case _Zone.wet:
        return "Above ${high.toStringAsFixed(0)}% — no watering needed";
      case _Zone.ideal:
        return "Within ${low.toStringAsFixed(0)}–${high.toStringAsFixed(0)}% target range";
    }
  }

  String get _zoneWord {
    switch (zone) {
      case _Zone.dry:
        return "DRY";
      case _Zone.wet:
        return "WET";
      case _Zone.ideal:
        return "IDEAL";
      case _Zone.offline:
        return "STALE";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _zoneColor(zone);
    final value = moisture.clamp(0, 100).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  "SOIL MOISTURE",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (live) const _LiveDot(),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 18,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 210,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: _GaugePainter(
                            value: animated,
                            low: low,
                            high: high,
                            color: color,
                            trackColor: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.07),
                            tickColor: isDark
                                ? Colors.white.withOpacity(0.55)
                                : Colors.black.withOpacity(0.45),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                animated.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 58,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: live
                                      ? theme.textTheme.bodyLarge?.color
                                      : theme.textTheme.bodyLarge?.color
                                          ?.withOpacity(0.5),
                                ),
                              ),
                              Text(
                                "%",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _zoneWord,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              _detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
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
            decoration: const BoxDecoration(
              color: _idealColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
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

class _GaugePainter extends CustomPainter {
  final double value; // 0..100
  final double low;
  final double high;
  final Color color;
  final Color trackColor;
  final Color tickColor;

  _GaugePainter({
    required this.value,
    required this.low,
    required this.high,
    required this.color,
    required this.trackColor,
    required this.tickColor,
  });

  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, _start, _sweep, false, track);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = _sweep * (value / 100).clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, _start, sweep, false, progress);
    }

    // Threshold ticks (low / high)
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = tickColor;
    for (final t in [low, high]) {
      final a = _start + _sweep * (t / 100).clamp(0.0, 1.0);
      final inner = radius - stroke / 2 - 5;
      final outer = radius + stroke / 2 + 5;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * inner,
        center + Offset(math.cos(a), math.sin(a)) * outer,
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value ||
      old.low != low ||
      old.high != high ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor;
}

// ===========================================================================
// PUMP CARD
// ===========================================================================
class _PumpCard extends StatelessWidget {
  final bool isOn;
  final bool isAuto;
  final bool autoIrrigation;
  final double low;
  final bool live;
  final bool isDark;

  const _PumpCard({
    required this.isOn,
    required this.isAuto,
    required this.autoIrrigation,
    required this.low,
    required this.live,
    required this.isDark,
  });

  String get _title {
    if (!live) return isOn ? "Last known: running" : "Last known: stopped";
    if (isOn) return "Watering now";
    if (isAuto && autoIrrigation) return "Standing by";
    return "Pump stopped";
  }

  String get _subtitle {
    if (!live) return "Pump state can't be confirmed while offline";
    if (isOn) return isAuto ? "Auto mode is irrigating" : "Running manually";
    if (isAuto && autoIrrigation) {
      return "Starts when soil drops below ${low.toStringAsFixed(0)}%";
    }
    if (isAuto) return "Automatic irrigation is turned off";
    return "Manual mode — switch it on from the Control tab";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = live && isOn;
    final color = !live
        ? _offlineColor
        : active
            ? AppColors.success
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active
              ? AppColors.success.withOpacity(0.45)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _PulsingIcon(active: active, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAuto ? "AUTO" : "MANUAL",
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final bool active;
  final Color color;

  const _PulsingIcon({required this.active, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulsingIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                Container(
                  width: 44 + 12 * t,
                  height: 44 + 12 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.28 * (1 - t)),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.active ? Icons.water_drop : Icons.water_drop_outlined,
                  color: widget.color,
                  size: 24,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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