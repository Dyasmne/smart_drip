import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/common/custom_appbar.dart';
import '../../widgets/common/tab_header.dart';

class HistoryScreen extends StatefulWidget {
  final bool isTab;

  const HistoryScreen({
    super.key,
    this.isTab = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  DatabaseReference get _logsRef =>
      FirebaseDatabase.instance.ref("smartdrip/irrigation_logs");

  void _enterSelectionMode([String? initialId]) {
    setState(() {
      _selectionMode = true;
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Map<String, dynamic>> logs) {
    setState(() {
      final allIds = logs.map((e) => e["id"] as String).toSet();
      final allSelected =
          _selectedIds.length == allIds.length && allIds.isNotEmpty;
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  // ================= DELETE SELECTED =================

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete $count record${count > 1 ? 's' : ''}?",
          style: AppTextStyles.h4,
        ),
        content: Text(
          "This action cannot be undone.",
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
              "Delete",
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.rust),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ids = List<String>.from(_selectedIds);
      for (final id in ids) {
        await _logsRef.child(id).remove();
      }

      if (context.mounted) {
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$count record${count > 1 ? 's' : ''} deleted")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete: $e")),
        );
      }
    }
  }

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

              // ================= SELECTION TOOLBAR =================
              // Shown inline (works for both isTab and pushed-route modes)
              // once selection mode is active, so the "select all / delete"
              // controls stay right above the list regardless of whether an
              // AppBar is present.
              if (_selectionMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.primary,
                        onPressed: _exitSelectionMode,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_selectedIds.length} selected",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _toggleSelectAll(logs),
                        child: Text(
                          _selectedIds.length == logs.length &&
                                  logs.isNotEmpty
                              ? "Deselect all"
                              : "Select all",
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: _selectedIds.isEmpty
                              ? Colors.grey
                              : AppColors.rust,
                        ),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _confirmDeleteSelected(context),
                      ),
                    ],
                  ),
                ),

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

                  // ===== SELECT + CLEAR BUTTONS (for isTab / no appbar case) =====
                  if (widget.isTab && logs.isNotEmpty && !_selectionMode) ...[
                    GestureDetector(
                      onTap: () => _enterSelectionMode(),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.checklist,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "Select",
                              style: AppTextStyles.labelMedium.copyWith(
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  ],

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
                  child: _eventCard(
                    log,
                    isDark,
                    selectionMode: _selectionMode,
                    isSelected: _selectedIds.contains(log["id"] as String),
                    onTap: () {
                      if (_selectionMode) {
                        _toggleSelected(log["id"] as String);
                      }
                    },
                    onLongPress: () {
                      if (!_selectionMode) {
                        _enterSelectionMode(log["id"] as String);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.isTab
          ? null
          : CustomAppBar(
              title: _selectionMode
                  ? "${_selectedIds.length} selected"
                  : "History",
              showBackButton: !_selectionMode,
              leading: _selectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _exitSelectionMode,
                    )
                  : null,
              actions: _selectionMode
                  ? [
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        tooltip: "Delete selected",
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _confirmDeleteSelected(context),
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.checklist, color: Colors.white),
                        tooltip: "Select",
                        onPressed: () => _enterSelectionMode(),
                      ),
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
      body: widget.isTab
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

  Widget _eventCard(
    Map<String, dynamic> log,
    bool isDark, {
    required bool selectionMode,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final bool isAuto = (log["action"] ?? "").toString().contains("AUTO");

    final double soil = (log["soil"] as num?)?.toDouble() ?? 0;
    final double temp = (log["temperature"] as num?)?.toDouble() ?? 0;
    final double humidity = (log["humidity"] as num?)?.toDouble() ?? 0;
    final int timestamp = (log["timestamp"] as num?)?.toInt() ?? 0;

    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.grey.shade400 : AppColors.textSecondary;
    final badgeColor = isAuto ? AppColors.moss : AppColors.water;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(isDark ? 0.18 : 0.1)
              : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.08) : AppColors.divider),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (selectionMode) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                backgroundColor:
                    isDark ? Colors.grey.shade800 : AppColors.divider,
              ),
            ),
          ],
        ),
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