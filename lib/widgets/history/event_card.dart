import 'package:flutter/material.dart';
import '../../models/irrigation_event.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

class EventCard extends StatelessWidget {
  final IrrigationEvent event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isAuto = event.mode == 'auto';
    final color =
        isAuto ? AppColors.primary : const Color(0xFF1565C0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAuto ? Icons.smart_toy : Icons.handyman,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppFormatters.formatDateTime(event.startTime),
                    style:
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  isAuto ? "AUTO" : "MANUAL",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mini("Duration", event.durationText),
                _mini("Before",
                    AppFormatters.formatMoisture(
                        event.moistureBefore)),
                _mini("After",
                    AppFormatters.formatMoisture(
                        event.moistureAfter)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}