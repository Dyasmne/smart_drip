import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/constants/app_colors.dart';
import '../../models/sensor_data.dart';

/// Line chart showing moisture trend over time (Firebase + ESP32 ready)
class MoistureChart extends StatelessWidget {
  final List<SensorData> data;
  final double height;

  const MoistureChart({
    super.key,
    required this.data,
    this.height = 200,
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

    final spots = _buildSpots();

    final minY = _safeMinY();
    final maxY = _safeMaxY();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,

          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
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

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: _xInterval(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();

                  final hour = data[i].timestamp.hour;
                  return Text(
                    '$hour',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 20,
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

          lineBarsData: [
            // MAIN LINE (ESP32 moisture)
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,

              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isEdge =
                      index == 0 || index == data.length - 1;

                  return FlDotCirclePainter(
                    radius: isEdge ? 4 : 0,
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

            // TARGET LINE (Firebase automation threshold)
            LineChartBarData(
              spots: [
                FlSpot(0, 60),
                FlSpot((data.length - 1).toDouble(), 60),
              ],
              isCurved: false,
              color: AppColors.success.withOpacity(0.5),
              barWidth: 1.5,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],

          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => AppColors.primary,
              getTooltipItems: (spots) {
                return spots.map((s) {
                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(1)}%',
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

  /// Convert sensor data → chart points
  List<FlSpot> _buildSpots() {
    return data.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        e.value.moisture.clamp(0, 100),
      );
    }).toList();
  }

  /// Safe min (prevents Firebase null/flat data crash)
  double _safeMinY() {
    final values = data.map((e) => e.moisture).toList();
    final min = values.reduce((a, b) => a < b ? a : b);

    final result = min - 10;
    return result.isNaN ? 0 : result.clamp(0, 100);
  }

  /// Safe max (prevents flat-line crash)
  double _safeMaxY() {
    final values = data.map((e) => e.moisture).toList();
    final max = values.reduce((a, b) => a > b ? a : b);

    final result = max + 10;
    return result.isNaN ? 100 : result.clamp(0, 100);
  }

  /// Adaptive spacing for ESP32 + Firebase streaming
  double _xInterval() {
    if (data.length <= 6) return 1;
    if (data.length <= 12) return 2;
    if (data.length <= 24) return 4;
    return 6;
  }
}