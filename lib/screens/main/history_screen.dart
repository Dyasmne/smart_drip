
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
      FirebaseDatabase.instance.ref('smartdrip/irrigation_logs');

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
      final allIds = logs.map((e) => e['id'] as String).toSet();
      final allSelected =
          allIds.isNotEmpty && allIds.every(_selectedIds.contains);

      if (allSelected) {
        _selectedIds.removeAll(allIds);
      } else {
        _selectedIds.addAll(allIds);
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete $count record${count > 1 ? 's' : ''}?',
          style: AppTextStyles.h4,
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.rust,
              ),
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

      if (!context.mounted) return;

      _exitSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count record${count > 1 ? 's' : ''} deleted',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
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
        title: Text(
          'Clear History?',
          style: AppTextStyles.h4,
        ),
        content: Text(
          'This will permanently delete all irrigation history '
          'records. This action cannot be undone.',
          style: AppTextStyles.body2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelLarge,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Clear',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.rust,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _logsRef.remove();

      if (mounted) {
        _exitSelectionMode();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear history: $e')),
        );
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
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load irrigation history.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2,
              ),
            ),
          );
        }

        final value = snapshot.data?.snapshot.value;

        if (value == null || value is! Map) {
          return _emptyState(isDark);
        }

        final List<Map<String, dynamic>> logs = [];

        value.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            map['id'] = key.toString();
            logs.add(map);
          }
        });

        // Newest valid timestamp first.
        // Supports numeric, numeric-string, and date-string timestamps.
        logs.sort((a, b) {
          final ta = _timestampMillis(a['timestamp']);
          final tb = _timestampMillis(b['timestamp']);
          return tb.compareTo(ta);
        });

        final totalEvents = logs.length;

        final autoEvents = logs.where((e) {
          return (e['action'] ?? '')
              .toString()
              .toUpperCase()
              .contains('AUTO');
        }).length;

        final manualEvents = totalEvents - autoEvents;

        // Remove selected IDs that no longer exist in Firebase.
        final existingIds = logs.map((e) => e['id'] as String).toSet();
        _selectedIds.removeWhere((id) => !existingIds.contains(id));

        return RefreshIndicator(
          onRefresh: () async {
            // Firebase onValue already listens for updates.
          },
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
                      value: '$totalEvents',
                      label: 'Total Events',
                    ),
                    _SummaryItem(
                      icon: Icons.smart_toy,
                      value: '$autoEvents',
                      label: 'Auto',
                    ),
                    _SummaryItem(
                      icon: Icons.build,
                      value: '$manualEvents',
                      label: 'Manual',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ================= SELECTION TOOLBAR =================

              if (_selectionMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(
                      isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
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
                        '${_selectedIds.length} selected',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _toggleSelectAll(logs),
                        child: Text(
                          logs.isNotEmpty &&
                                  logs.every(
                                    (e) => _selectedIds.contains(e['id']),
                                  )
                              ? 'Deselect all'
                              : 'Select all',
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

              // ================= RECENT EVENTS HEADER =================

              Row(
                children: [
                  Text(
                    'Recent Events',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 16,
                      color: isDark
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),

                  if (widget.isTab &&
                      logs.isNotEmpty &&
                      !_selectionMode) ...[
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
                              'Select',
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
                              'Clear',
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
                      '$totalEvents records',
                      style: AppTextStyles.dataSmall.copyWith(
                        fontSize: 10.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (logs.isEmpty)
                _emptyState(isDark)
              else
                ...logs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _eventCard(
                      log,
                      isDark,
                      selectionMode: _selectionMode,
                      isSelected: _selectedIds.contains(log['id']),
                      onTap: () {
                        if (_selectionMode) {
                          _toggleSelected(log['id'] as String);
                        }
                      },
                      onLongPress: () {
                        if (!_selectionMode) {
                          _enterSelectionMode(log['id'] as String);
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
                  ? '${_selectedIds.length} selected'
                  : 'History',
              showBackButton: !_selectionMode,
              leading: _selectionMode
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      onPressed: _exitSelectionMode,
                    )
                  : null,
              actions: _selectionMode
                  ? [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        tooltip: 'Delete selected',
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _confirmDeleteSelected(context),
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(
                          Icons.checklist,
                          color: Colors.white,
                        ),
                        tooltip: 'Select',
                        onPressed: () => _enterSelectionMode(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          color: Colors.white,
                        ),
                        tooltip: 'Clear history',
                        onPressed: () => _confirmClearHistory(context),
                      ),
                    ],
            ),
      body: widget.isTab
          ? Column(
              children: [
                const TabHeader(title: 'History'),
                Expanded(child: streamContent),
              ],
            )
          : streamContent,
    );
  }

  // ================= EMPTY STATE =================

  Widget _emptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'No irrigation history yet',
              style: AppTextStyles.h3.copyWith(
                fontSize: 15,
                color: isDark
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'History will appear here automatically.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2,
            ),
          ],
        ),
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
    final action = (log['action'] ?? '').toString();
    final normalizedAction = action.toUpperCase();

    final bool isAuto = normalizedAction.contains('AUTO');
    final bool pumpIsOn = normalizedAction.endsWith('ON');

    final double soil = _toNum(log['soil']).toDouble();
    final String formattedTimestamp =
        _formatTimestamp(log['timestamp']);

    final bool hasLowThreshold = log['lowThreshold'] != null;
    final bool hasHighThreshold = log['highThreshold'] != null;

    final num lowThreshold = _toNum(log['lowThreshold']);
    final num highThreshold = _toNum(log['highThreshold']);

    final cardColor = isDark
        ? AppColors.cardDark
        : AppColors.cardLight;

    final textColor =
        isDark ? Colors.white : AppColors.textPrimary;

    final subtextColor = isDark
        ? Colors.grey.shade400
        : AppColors.textSecondary;

    final badgeColor = isAuto
        ? AppColors.moss
        : AppColors.water;

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
                : (isDark
                    ? Colors.white.withOpacity(0.08)
                    : AppColors.divider),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= EVENT HEADER =================

            Row(
              children: [
                if (selectionMode) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                ],
                CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      badgeColor.withOpacity(isDark ? 0.18 : 0.1),
                  child: Icon(
                    isAuto
                        ? Icons.smart_toy
                        : Icons.touch_app,
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
                        formattedTimestamp,
                        style: AppTextStyles.dataSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.isEmpty ? 'Irrigation event' : action,
                        style: AppTextStyles.body2.copyWith(
                          color: subtextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(
                      isDark ? 0.18 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAuto ? 'AUTO' : 'MANUAL',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 9,
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            // ================= THRESHOLDS =================

            if (isAuto &&
                (hasLowThreshold || hasHighThreshold)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (hasLowThreshold)
                    _thresholdChip(
                      label:
                          'Min: ${lowThreshold.toStringAsFixed(0)}%',
                      icon: Icons.arrow_downward,
                      isDark: isDark,
                      textColor: subtextColor,
                    ),
                  if (hasHighThreshold)
                    _thresholdChip(
                      label:
                          'Stop: ${highThreshold.toStringAsFixed(0)}%',
                      icon: Icons.arrow_upward,
                      isDark: isDark,
                      textColor: subtextColor,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ================= SOIL AND PUMP STATUS =================

            Row(
              children: [
                Expanded(
                  child: _metric(
                    Icons.water_drop,
                    '${soil.toStringAsFixed(0)}%',
                    'Soil Moisture',
                    AppColors.clay,
                    textColor,
                    subtextColor,
                  ),
                ),
                Expanded(
                  child: _metric(
                    Icons.power_settings_new,
                    pumpIsOn ? 'ON' : 'OFF',
                    'Pump Status',
                    pumpIsOn ? AppColors.moss : subtextColor,
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
                value: (soil / 100).clamp(0.0, 1.0),
                minHeight: 5,
                color: AppColors.moss,
                backgroundColor: isDark
                    ? Colors.grey.shade800
                    : AppColors.divider,
              ),
            ),

            // ================= EVENT REASON =================

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.divider.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _eventReason(
                        action,
                        log['lowThreshold'],
                        log['highThreshold'],
                      ),
                      style: AppTextStyles.body2.copyWith(
                        color: subtextColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= THRESHOLD CHIP =================

  Widget _thresholdChip({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : AppColors.divider,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600,
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
            fontSize: 14,
            color: textColor,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: subtextColor,
          ),
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
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// ================= NUMBER COERCION =================

num _toNum(dynamic value) {
  if (value is num) return value;

  if (value is String) {
    return num.tryParse(value.trim()) ?? 0;
  }

  return 0;
}

// ================= TIMESTAMP HELPERS =================

int _timestampMillis(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    final number = value.toInt();

    // Unix seconds -> milliseconds.
    if (number > 0 && number < 100000000000) {
      return number * 1000;
    }

    return number;
  }

  if (value is String) {
    final text = value.trim();

    if (text.isEmpty) return 0;

    // Numeric timestamp stored as a String.
    final number = num.tryParse(text);

    if (number != null) {
      final millis = number.toInt();

      if (millis > 0 && millis < 100000000000) {
        return millis * 1000;
      }

      return millis;
    }

    // Supports ISO timestamps and strings such as:
    // 2026-09-26 08:30:00
    final parsedDate = DateTime.tryParse(text);

    if (parsedDate != null) {
      return parsedDate.millisecondsSinceEpoch;
    }
  }

  return 0;
}

String _formatTimestamp(dynamic value) {
  final millis = _timestampMillis(value);

  if (millis <= 0) {
    return 'Unknown Date';
  }

  final date = DateTime.fromMillisecondsSinceEpoch(millis);

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final month = months[date.month - 1];

  int hour = date.hour % 12;
  if (hour == 0) hour = 12;

  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$month ${date.day}, ${date.year} • $hour:$minute $period';
}

// ================= EVENT REASON =================

String _eventReason(
  String action,
  dynamic lowValue,
  dynamic highValue,
) {
  final normalized = action.toUpperCase();

  if (normalized.contains('AUTO ON')) {
    if (lowValue != null) {
      final low = _toNum(lowValue);

      return 'Automatic irrigation started because soil '
          'moisture reached or fell below the minimum '
          'threshold of ${low.toStringAsFixed(0)}%.';
    }

    return 'Automatic irrigation started due to low soil moisture.';
  }

  if (normalized.contains('AUTO OFF')) {
    if (highValue != null) {
      final high = _toNum(highValue);

      return 'Automatic irrigation stopped because soil '
          'moisture reached the stop threshold of '
          '${high.toStringAsFixed(0)}%.';
    }

    return 'Automatic irrigation stopped after reaching '
        'the stop condition.';
  }

  if (normalized.contains('MANUAL ON')) {
    return 'The pump was turned on manually.';
  }

  if (normalized.contains('MANUAL OFF')) {
    return 'The pump was turned off manually.';
  }

  return 'Irrigation event recorded.';
}