import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';

class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({super.key});

  @override
  State<AdminActivityLogsScreen> createState() =>
      _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState
    extends State<AdminActivityLogsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        centerTitle: true,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, child) {
          if (admin.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (admin.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      admin.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        admin.loadAdminData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final logs = admin.activityLogs.entries.toList();

          if (logs.isEmpty) {
            return RefreshIndicator(
              onRefresh: admin.loadAdminData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.history, size: 64),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No activity logs yet.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          logs.sort((a, b) {
            final aTime = _parseDate(_extractTimestamp(a.value));
            final bTime = _parseDate(_extractTimestamp(b.value));

            return bTime.compareTo(aTime);
          });

          return RefreshIndicator(
            onRefresh: admin.loadAdminData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index].value;

                if (log is! Map) {
                  return const SizedBox.shrink();
                }

                return _buildActivityCard(log, logs[index].key);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityCard(dynamic log, String logId) {
    final action = log['action']?.toString() ?? 'Unknown Activity';
    final name = log['name']?.toString() ??
        log['userName']?.toString() ??
        'Unknown User';
    final email = log['email']?.toString() ?? '';
    final timestamp = _extractTimestamp(log);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _iconColorFor(action).withOpacity(.12),
          child: Icon(
            _iconFor(action),
            color: _iconColorFor(action),
          ),
        ),
        title: Text(
          action,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(name),
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // TIMESTAMP HANDLING
  //
  // Confirmed from smartdrip/irrigation_logs that this project
  // stores timestamps as a STRING OF EPOCH-MILLISECOND DIGITS
  // (e.g. "1788604195000"), not as ISO-8601. The original
  // DateTime.tryParse(value.toString()) silently fails on that
  // format and falls back to epoch 0, so every row showed
  // "No date" and sorting was effectively random. This also
  // checks a couple of alternate field/key names defensively.
  // ==============================================================

  dynamic _extractTimestamp(dynamic log) {
    if (log is! Map) return null;

    return log['timestamp'] ??
        log['time'] ??
        log['lastUpdated'] ??
        log['updatedAt'] ??
        log['createdAt'];
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    final text = value.toString();

    final asMillis = int.tryParse(text);

    if (asMillis != null && text.length >= 10) {
      // 10-digit strings are epoch seconds, 13-digit are millis.
      final millis = text.length <= 10 ? asMillis * 1000 : asMillis;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    final parsed = DateTime.tryParse(text);

    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'No date';
    }

    final date = _parseDate(value).toLocal();

    if (date.millisecondsSinceEpoch == 0) {
      return 'No date';
    }

    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${hour12.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} $period';
  }

  // ==============================================================
  // ICON / COLOR PER ACTION TYPE (purely cosmetic, safe defaults)
  // ==============================================================

  IconData _iconFor(String action) {
    final a = action.toLowerCase();

    if (a.contains('manual')) return Icons.touch_app_outlined;
    if (a.contains('auto')) return Icons.autorenew;
    if (a.contains('login') || a.contains('logged in')) {
      return Icons.login;
    }
    if (a.contains('register')) return Icons.person_add_outlined;
    if (a.contains('setting')) return Icons.settings_outlined;
    if (a.contains('pump')) return Icons.water_drop_outlined;

    return Icons.history;
  }

  Color _iconColorFor(String action) {
    final a = action.toLowerCase();

    if (a.contains('on')) return Colors.blue.shade600;
    if (a.contains('off')) return Colors.grey.shade600;
    if (a.contains('login')) return Colors.green.shade600;
    if (a.contains('register')) return Colors.purple.shade600;

    return Colors.grey.shade700;
  }
}