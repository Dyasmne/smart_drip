import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/sensor_provider.dart';

enum SoilZone { dry, ideal, wet, offline }

/// Single source of truth for soil zones + colors (Home and Monitor).
class SoilZones {
  static const double defaultLow = 30;
  static const double defaultHigh = 70;

  static SoilZone of(
    double moisture, {
    required double low,
    required double high,
    required bool live,
  }) {
    if (!live) return SoilZone.offline;
    if (moisture < low) return SoilZone.dry;
    if (moisture > high) return SoilZone.wet;
    return SoilZone.ideal;
  }

  /// Same "is the ESP32 live?" rule as the Home tab.
  static const Duration liveThreshold = Duration(minutes: 2);

  /// Zone for the current sensor state. Every screen header uses this,
  /// so the color is always identical across the app.
  static SoilZone fromSensor(SensorProvider s) {
    final updated = s.lastUpdated;
    final live = updated != null &&
        DateTime.now().difference(updated) < liveThreshold;
    return of(
      s.moisture.toDouble(),
      low: s.lowThreshold ?? defaultLow,
      high: s.highThreshold ?? defaultHigh,
      live: live,
    );
  }

  /// Current zone for any widget. Falls back to the green "ideal" look
  /// when no SensorProvider exists (e.g. login screens).
  static SoilZone currentOf(BuildContext context) {
    try {
      return context.select<SensorProvider, SoilZone>(fromSensor);
    } catch (_) {
      return SoilZone.ideal;
    }
  }

  static Color color(SoilZone z) {
    switch (z) {
      case SoilZone.dry:
        return const Color(0xFFEF6C00);
      case SoilZone.ideal:
        return const Color(0xFF2E7D32);
      case SoilZone.wet:
        return const Color(0xFF1976D2);
      case SoilZone.offline:
        return const Color(0xFF607D8B);
    }
  }

  static List<Color> gradient(SoilZone z) {
    switch (z) {
      case SoilZone.dry:
        return const [Color(0xFFE65100), Color(0xFFEF6C00), Color(0xFFFB8C00)];
      case SoilZone.wet:
        return const [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)];
      case SoilZone.offline:
        return const [Color(0xFF37474F), Color(0xFF455A64), Color(0xFF607D8B)];
      case SoilZone.ideal:
        return const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)];
    }
  }

  static String label(SoilZone z) {
    switch (z) {
      case SoilZone.dry:
        return 'Dry';
      case SoilZone.ideal:
        return 'Ideal';
      case SoilZone.wet:
        return 'Wet';
      case SoilZone.offline:
        return 'Offline';
    }
  }
}

/// The one header used by every screen. It reads the soil state itself,
/// so a screen only needs: appBar: const ZoneAppBar(title: 'History')
class ZoneAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  /// Optional override; normally leave null.
  final SoilZone? zone;

  const ZoneAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.zone,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final z = zone ?? SoilZones.currentOf(context);
    final gradient = SoilZones.gradient(z);

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
      actions: actions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: gradient.first,
      elevation: 0,
      flexibleSpace: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
        ),
      ),
    );
  }
}