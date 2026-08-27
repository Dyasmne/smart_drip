import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/sensor_provider.dart';
import '../../providers/irrigation_provider.dart';

/// Shows a card-styled dialog with live system connectivity + pump status,
/// pulled from the existing SensorProvider / IrrigationProvider (which are
/// already backed by Firebase Realtime Database).
class SystemStatusDialog extends StatelessWidget {
  const SystemStatusDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const SystemStatusDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Consumer2<SensorProvider, IrrigationProvider>(
        builder: (context, sensor, irrigation, _) {
          // SensorProvider already tracks this directly: `isOnline` is set
          // true whenever a valid sensor reading is parsed, and flipped to
          // false by its own 10-minute offline watcher (or a stream/parse
          // error), so we use it as-is instead of re-deriving it here.
          final esp32Online = sensor.isOnline;

          // The listener itself is the Firebase connection; if it's live
          // and hasn't surfaced an error, treat it as connected.
          final firebaseConnected =
              sensor.isOnline || sensor.errorMessage == null;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.wifi, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "System Status",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      splashRadius: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _statusRow("ESP32 Device", esp32Online),
                const Divider(height: 24),
                _statusRow("WiFi Connection", esp32Online),
                const Divider(height: 24),
                _statusRow("Firebase Connection", firebaseConnected),
                const Divider(height: 24),
                _statusRow(
                  "Water Pump",
                  irrigation.isPumpOn,
                  onLabel: "ON",
                  offLabel: "OFF",
                ),
                if (sensor.lastUpdated != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Last data received: ${AppFormatters.formatRelativeTime(sensor.lastUpdated!)}",
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusRow(
    String label,
    bool isPositive, {
    String onLabel = "Online",
    String offLabel = "Offline",
  }) {
    final color = isPositive ? AppColors.success : Colors.red;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              isPositive ? onLabel : offLabel,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ],
    );
  }
}