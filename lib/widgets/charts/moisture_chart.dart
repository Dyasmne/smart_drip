import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/constants/app_colors.dart';
import '../../models/sensor_data.dart';

/// Line chart showing moisture trend over time (Firebase + ESP32 ready).
///
/// [data] must be ordered oldest -> newest.
/// [lowThreshold] / [highThreshold] draw dashed lines when not null.
class MoistureChart extends StatelessWidget {
  final List<SensorData> data;
  final double height;
  final double? lowThreshold;
  final double? highThreshold;

  static const Color lowColor = Color(0xFFFB8C00);
  static const Color highColor = Color(0xFF1E88E5);

  const MoistureChart({
    super.key,
    required this.data,
    this.height = 200,
    this.lowThreshold,
    this.highThreshold,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Waiting for sensor data...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // A line needs at least 2 points. With a single reading, draw a
    // flat line from that same reading so the chart never shows just
    // a lone dot.
    final points = data.length == 1 ? [data.first, data.first] : data;

    final spots = _buildSpots(points);

    final minY = _safeMinY(points);
    final maxY = _safeMaxY(points);
    final yInterval = (maxY - minY) > 50 ? 20.0 : 10.0;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,

          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.primary.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),

          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            // ================= X-AXIS (TIME LABELS) =================
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _xInterval(points.length),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatTime(points[i].timestamp),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),

          borderData: FlBorderData(show: false),

          // ================= THRESHOLD LINES =================
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (lowThreshold != null)
                HorizontalLine(
                  y: lowThreshold!,
                  color: lowColor.withOpacity(0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
              if (highThreshold != null)
                HorizontalLine(
                  y: highThreshold!,
                  color: highColor.withOpacity(0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
            ],
          ),

          lineBarsData: [
            // MAIN LINE (ESP32 moisture)
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,

              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isFirst = index == 0;
                  final isLast = index == points.length - 1;

                  return FlDotCirclePainter(
                    radius: isLast ? 5 : (isFirst ? 3.5 : 0),
                    color: AppColors.primary,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                  );
                },
              ),

              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.25),
                    AppColors.primary.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],

          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.primary,
              getTooltipItems: (touched) {
                return touched.map((s) {
                  final i = s.x.toInt();
                  final timeLabel = (i >= 0 && i < points.length)
                      ? _formatTime(points[i].timestamp)
                      : '';

                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(1)}%\n$timeLabel',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  /// Convert sensor data -> chart points
  List<FlSpot> _buildSpots(List<SensorData> points) {
    return points.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        e.value.moisture.clamp(0, 100).toDouble(),
      );
    }).toList();
  }

  /// Lowest value shown (includes thresholds so the lines are visible),
  /// rounded down to a multiple of 10 so axis labels stay clean.
  double _safeMinY(List<SensorData> points) {
    var lowest = points.map((e) => e.moisture).reduce(math.min);

    if (lowThreshold != null) lowest = math.min(lowest, lowThreshold!);
    if (highThreshold != null) lowest = math.min(lowest, highThreshold!);

    final result = ((lowest - 10) / 10).floor() * 10.0;

    return result.isNaN ? 0 : result.clamp(0, 90).toDouble();
  }

  /// Highest value shown, rounded up to a multiple of 10.
  double _safeMaxY(List<SensorData> points) {
    var highest = points.map((e) => e.moisture).reduce(math.max);

    if (lowThreshold != null) highest = math.max(highest, lowThreshold!);
    if (highThreshold != null) highest = math.max(highest, highThreshold!);

    var result = ((highest + 10) / 10).ceil() * 10.0;

    if (result.isNaN) return 100;

    result = result.clamp(10, 100).toDouble();

    // keep at least a 20% span so a flat line doesn't crush the axis
    final minY = _safeMinY(points);
    if (result - minY < 20) {
      result = math.min(100, minY + 20);
    }

    return result;
  }

  /// Adaptive spacing for time labels.
  double _xInterval(int length) {
    if (length <= 4) return 1;
    if (length <= 8) return 2;
    if (length <= 16) return 3;
    if (length <= 30) return 6;
    return (length / 5).ceilToDouble();
  }

  /// "8:00 AM" style time label
  String _formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $period';
  }
}