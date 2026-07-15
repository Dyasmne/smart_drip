import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/common/custom_appbar.dart';
import '../../widgets/common/tab_header.dart';

class HistoryScreen extends StatelessWidget {
  final bool isTab;

  const HistoryScreen({
    super.key,
    this.isTab = false,
  });

  DatabaseReference get _logsRef =>
      FirebaseDatabase.instance.ref("smartdrip/irrigation_logs");

  // ================= CLEAR HISTORY =================

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text("Clear History?", style: AppTextStyles.h4),
        content: Text(
          "This will permanently delete all irrigation history records. This action cannot be undone.",
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: AppTextStyles.labelLarge),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Clear",
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.rust),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _logsRef.remove();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("History cleared")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to clear history: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final streamContent = StreamBuilder<DatabaseEvent>(
      stream: _logsRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _emptyState(isDark);
        }

        final raw =
            Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);

        final List<Map<String, dynamic>> logs = [];

        raw.forEach((key, value) {
          final map = Map<String, dynamic>.from(value);

          map["id"] = key;

          logs.add(map);
        });

        logs.sort((a, b) {
          final ta = a["timestamp"] ?? 0;
          final tb = b["timestamp"] ?? 0;

          return tb.compareTo(ta);
        });

        final totalEvents = logs.length;

        final autoEvents = logs.where((e) {
          return (e["action"] ?? "").toString().contains("AUTO");
        }).length;

        final manualEvents = totalEvents - autoEvents;

        return RefreshIndicator(
          onRefresh: () async {},
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ================= SUMMARY =================

              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.mossDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryItem(
                      icon: Icons.event_note,
                      value: "$totalEvents",
                      label: "Total Events",
                    ),
                    _SummaryItem(
                      icon: Icons.smart_toy,
                      value: "$autoEvents",
                      label: "Auto",
                    ),
                    _SummaryItem(
                      icon: Icons.build,
                      value: "$manualEvents",
                      label: "Manual",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Text(
                    "Recent Events",
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 16, // was default h2 size (18)
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),

                  // ===== CLEAR BUTTON (for isTab / no appbar case) =====
                  if (isTab && logs.isNotEmpty)
                    GestureDetector(
                      onTap: () => _confirmClearHistory(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.rust.withOpacity(0.15)
                              : AppColors.rust.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_sweep_outlined,
                              size: 14,
                              color: AppColors.rust,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "Clear",
                              style: AppTextStyles.labelMedium.copyWith(
                                fontSize: 10.5,
                                color: AppColors.rust,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$totalEvents records",
                      style: AppTextStyles.dataSmall.copyWith(
                        fontSize: 10.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              ...logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _eventCard(log, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: isTab
          ? null
          : CustomAppBar(
              title: "History",
              showBackButton: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.white,
                  ),
                  tooltip: "Clear history",
                  onPressed: () => _confirmClearHistory(context),
                ),
              ],
            ),
      body: isTab
          ? Column(
              children: [
                const TabHeader(title: "History"),
                Expanded(child: streamContent),
              ],
            )
          : streamContent,
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 14),
          Text(
            "No irrigation history yet",
            style: AppTextStyles.h3.copyWith(
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "History will appear here automatically.",
            style: AppTextStyles.body2,
          ),
        ],
      ),
    );
  }

  // ================= EVENT CARD =================

  Widget _eventCard(Map<String, dynamic> log, bool isDark) {
    final bool isAuto = (log["action"] ?? "").toString().contains("AUTO");

    final double soil = (log["soil"] as num?)?.toDouble() ?? 0;
    final double temp = (log["temperature"] as num?)?.toDouble() ?? 0;
    final double humidity = (log["humidity"] as num?)?.toDouble() ?? 0;
    final int timestamp = (log["timestamp"] as num?)?.toInt() ?? 0;

    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.grey.shade400 : AppColors.textSecondary;
    final badgeColor = isAuto ? AppColors.moss : AppColors.water;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: badgeColor.withOpacity(isDark ? 0.18 : 0.1),
                child: Icon(
                  isAuto ? Icons.smart_toy : Icons.touch_app,
                  color: badgeColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTimestamp(timestamp),
                      style: AppTextStyles.dataSmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log["action"] ?? "",
                      style: AppTextStyles.body2.copyWith(
                        color: subtextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAuto ? "AUTO" : "MANUAL",
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 9,
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.water_drop,
                  "$soil%",
                  "Soil",
                  AppColors.clay,
                  textColor,
                  subtextColor,
                ),
              ),
              Expanded(
                child: _metric(
                  Icons.thermostat,
                  "$temp°C",
                  "Temp",
                  AppColors.rust,
                  textColor,
                  subtextColor,
                ),
              ),
              Expanded(
                child: _metric(
                  Icons.water,
                  "$humidity%",
                  "Humidity",
                  AppColors.water,
                  textColor,
                  subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: soil / 100,
              minHeight: 5,
              color: AppColors.moss,
              backgroundColor: isDark ? Colors.grey.shade800 : AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }

  // ================= METRIC =================

  Widget _metric(
    IconData icon,
    String value,
    String label,
    Color color,
    Color textColor,
    Color subtextColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 5),
        Text(
          value,
          style: AppTextStyles.dataMedium.copyWith(
            fontSize: 14, // was default dataMedium size (16)
            color: textColor,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: subtextColor),
        ),
      ],
    );
  }
}

// ================= SUMMARY ITEM =================

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.dataLarge.copyWith(
            color: Colors.white,
            fontSize: 20, // was 26
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

// ================= TIMESTAMP FORMAT =================

String _formatTimestamp(int timestamp) {
  if (timestamp == 0) {
    return "Unknown Date";
  }

  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];

  final month = months[date.month - 1];

  int hour = date.hour % 12;
  if (hour == 0) hour = 12;

  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? "PM" : "AM";

  return "$month ${date.day}, ${date.year} • $hour:$minute $period";
}