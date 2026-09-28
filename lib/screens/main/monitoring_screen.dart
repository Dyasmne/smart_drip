import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/soil_zones.dart';
import '../../core/utils/formatters.dart';
import '../../models/sensor_data.dart';
import '../../providers/sensor_provider.dart';
import '../../widgets/charts/moisture_chart.dart';
import '../../widgets/dashboard/irrigation_analytics_card.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SensorProvider>(
      builder: (context, sensor, child) {
        final double moisture = sensor.moisture.toDouble();
        final double low = sensor.lowThreshold ?? SoilZones.defaultLow;
        final double high = sensor.highThreshold ?? SoilZones.defaultHigh;
        final SoilZone zone = SoilZones.of(
          moisture,
          low: low,
          high: high,
          live: sensor.isOnline,
        );

        // chartData is newest-first -> reverse for oldest -> newest
        final chartData = sensor.chartData.reversed.toList();

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: ZoneAppBar(title: 'Monitoring', zone: zone),
          body: RefreshIndicator(
            onRefresh: sensor.refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  _heroCard(context, sensor, moisture, zone, chartData, low, high),
                  const SizedBox(height: 14),
                  _statsRow(context, chartData),
                  const SizedBox(height: 14),
                  _trendCard(context, chartData, low, high),
                  const SizedBox(height: 14),
                  _pumpCard(context, sensor),
                  const SizedBox(height: 14),
                  IrrigationAnalyticsCard(
                    currentMoisture: moisture,
                    lowThreshold: sensor.lowThreshold,
                    pumpOn: sensor.pumpStatus,
                    isOnline: sensor.isOnline,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HERO: GAUGE + STATUS + ZONE BAR
  // ============================================================

  Widget _heroCard(
    BuildContext context,
    SensorProvider sensor,
    double moisture,
    SoilZone zone,
    List<SensorData> chartData,
    double low,
    double high,
  ) {
    final pct = (moisture / 100).clamp(0.0, 1.0).toDouble();
    final zoneColor = SoilZones.color(zone);

    return _card(
      context,
      child: Column(
        children: [
          // ---- online + last updated -------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: sensor.isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _updatedLabel(sensor),
                style: TextStyle(
                  color: sensor.isOnline ? Colors.green : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---- circular gauge --------------------------------
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 14,
                    color: zoneColor.withOpacity(.12),
                  ),
                ),
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        color: zoneColor,
                        backgroundColor: Colors.transparent,
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.water_drop, color: zoneColor, size: 28),
                    const SizedBox(height: 2),
                    Text(
                      "${moisture.toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: zoneColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Soil Moisture",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ---- status chip + trend ---------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  SoilZones.label(zone),
                  style: TextStyle(
                    color: zoneColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _trendBadge(chartData),
            ],
          ),

          const SizedBox(height: 22),

          _zoneBar(moisture, low, high, zone),
        ],
      ),
    );
  }

  String _updatedLabel(SensorProvider sensor) {
    final updated = sensor.lastUpdated;

    if (updated == null) {
      return sensor.isOnline ? "Live" : "No data yet";
    }

    final rel = AppFormatters.formatRelativeTime(updated);
    return sensor.isOnline ? "Live · $rel" : "Offline · last seen $rel";
  }

  Widget _trendBadge(List<SensorData> chartData) {
    if (chartData.length < 2) return const SizedBox.shrink();

    final diff = chartData.last.moisture - chartData.first.moisture;

    IconData icon;
    Color color;
    String text;

    if (diff.abs() < 0.5) {
      icon = Icons.trending_flat;
      color = Colors.grey;
      text = "Steady";
    } else if (diff > 0) {
      icon = Icons.trending_up;
      color = SoilZones.color(SoilZone.wet);
      text = "+${diff.toStringAsFixed(1)}%";
    } else {
      icon = Icons.trending_down;
      color = SoilZones.color(SoilZone.dry);
      text = "${diff.toStringAsFixed(1)}%";
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Zone bar that follows the low/high thresholds from settings.
  Widget _zoneBar(double moisture, double low, double high, SoilZone active) {
    final pct = (moisture / 100).clamp(0.0, 1.0).toDouble();
    final segs = <_Seg>[
      _Seg(SoilZone.dry, 0, low),
      _Seg(SoilZone.ideal, low, high),
      _Seg(SoilZone.wet, high, 100),
    ];

    // While offline the active zone is "offline"; highlight by real position.
    final highlighted = active == SoilZone.offline
        ? SoilZones.of(moisture, low: low, high: high, live: true)
        : active;
    final markerColor = SoilZones.color(active);

    return LayoutBuilder(
      builder: (context, c) {
        final markerX =
            (pct * c.maxWidth).clamp(7.0, c.maxWidth - 7.0).toDouble();

        return Column(
          children: [
            SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 7,
                    left: 0,
                    right: 0,
                    child: Row(
                      children: segs.map((s) {
                        final isActive = s.zone == highlighted;
                        final col = SoilZones.color(s.zone);
                        return Expanded(
                          flex: (s.to - s.from).round().clamp(1, 100),
                          child: Container(
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: isActive ? col : col.withOpacity(.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Positioned(
                    left: markerX - 7,
                    top: 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: markerColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.black.withOpacity(.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: segs.map((s) {
                final isActive = s.zone == highlighted;
                final col = SoilZones.color(s.zone);
                return Expanded(
                  flex: (s.to - s.from).round().clamp(1, 100),
                  child: Column(
                    children: [
                      Text(
                        SoilZones.label(s.zone),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive ? col : Colors.grey,
                        ),
                      ),
                      Text(
                        "${s.from.toInt()}-${s.to.toInt()}%",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isActive
                              ? col.withOpacity(.8)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MIN / AVG / MAX
  // ============================================================

  Widget _statsRow(BuildContext context, List<SensorData> chartData) {
    String fmt(double? v) => v == null ? "--" : "${v.toStringAsFixed(1)}%";

    double? minV;
    double? maxV;
    double? avgV;

    if (chartData.isNotEmpty) {
      final values = chartData.map((e) => e.moisture.toDouble()).toList();
      minV = values.reduce((a, b) => a < b ? a : b);
      maxV = values.reduce((a, b) => a > b ? a : b);
      avgV = values.reduce((a, b) => a + b) / values.length;
    }

    return Row(
      children: [
        Expanded(
          child: _statTile(context, "Lowest", fmt(minV), Icons.arrow_downward,
              SoilZones.color(SoilZone.dry)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(context, "Average", fmt(avgV), Icons.remove,
              SoilZones.color(SoilZone.ideal)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(context, "Highest", fmt(maxV), Icons.arrow_upward,
              SoilZones.color(SoilZone.wet)),
        ),
      ],
    );
  }

  Widget _statTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TREND CHART
  // ============================================================

  Widget _trendCard(
    BuildContext context,
    List<SensorData> chartData,
    double low,
    double high,
  ) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Moisture Trend",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 14),
          MoistureChart(
            data: chartData,
            height: 210,
            lowThreshold: low,
            highThreshold: high,
          ),
          if (chartData.length < 3) ...[
            const SizedBox(height: 10),
            const Text(
              "Collecting data… the trend fills in as new readings arrive.",
              style: TextStyle(color: Colors.grey, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _lineLegend(
                MoistureChart.lowColor,
                "Pump ON below ${low.toStringAsFixed(0)}%",
              ),
              _lineLegend(
                MoistureChart.highColor,
                "Pump OFF at ${high.toStringAsFixed(0)}%",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lineLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
      ],
    );
  }

  // ============================================================
  // PUMP STATUS
  // ============================================================

  Widget _pumpCard(BuildContext context, SensorProvider sensor) {
    final on = sensor.pumpStatus;
    final mode = sensor.pumpMode;
    final live = sensor.isOnline;

    final color = !live
        ? SoilZones.color(SoilZone.offline)
        : on
            ? SoilZones.color(SoilZone.wet)
            : Colors.grey;

    final status = !live ? (on ? "Last known: ON" : "Last known: OFF") : (on ? "Irrigating" : "Idle");

    return _card(
      context,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.water, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Water Pump",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill(on ? "ON" : "OFF", color),
              if (mode != null) ...[
                const SizedBox(height: 6),
                _pill(mode.toString(), const Color(0xFF546E7A)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // SHARED CARD STYLE
  // ============================================================

  static final List<BoxShadow> _shadow = [
    BoxShadow(
      blurRadius: 20,
      color: Colors.black.withOpacity(.05),
    ),
  ];

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: child,
    );
  }
}

class _Seg {
  final SoilZone zone;
  final double from;
  final double to;
  const _Seg(this.zone, this.from, this.to);
}