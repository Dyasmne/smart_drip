import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common/custom_appbar.dart';

/// Notifications screen – shows all system alerts and messages.
///
/// Supports a selection mode (long-press a card, or tap "Select" in the
/// app bar) that lets the user pick specific notifications and delete
/// only those, separate from "Clear All" (deletes everything) and the
/// existing swipe-to-dismiss (deletes just the one swiped).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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

  void _toggleSelectAll(List<NotificationModel> notifications) {
    setState(() {
      final allIds = notifications.map((n) => n.id).toSet();
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

  Future<void> _confirmDeleteSelected(
    BuildContext context,
    NotificationProvider provider,
  ) async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete $count notification${count > 1 ? 's' : ''}?"),
        content: const Text(
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ids = List<String>.from(_selectedIds);
    for (final id in ids) {
      await provider.deleteNotification(id);
    }

    if (context.mounted) {
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$count notification${count > 1 ? 's' : ''} deleted")),
      );
    }
  }

  // ================= CLEAR ALL =================

  Future<void> _confirmClearAll(
    BuildContext context,
    NotificationProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Clear All Notifications?"),
        content: const Text(
          "This will permanently delete all notifications. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Clear",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _selectionMode ? '${_selectedIds.length} selected' : 'Notifications',
        showBackButton: !_selectionMode,
        // In selection mode the back chevron becomes a "cancel selection"
        // action instead of leaving the screen.
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                final allIds = provider.notifications.map((n) => n.id).toSet();
                final allSelected =
                    _selectedIds.length == allIds.length && allIds.isNotEmpty;
                return TextButton(
                  onPressed: () => _toggleSelectAll(provider.notifications),
                  child: Text(
                    allSelected ? 'Deselect all' : 'Select all',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                return IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: "Delete selected",
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _confirmDeleteSelected(context, provider),
                );
              },
            ),
          ] else ...[
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (!provider.hasUnread) return const SizedBox();
                return TextButton(
                  onPressed: provider.markAllRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.notifications.isEmpty) return const SizedBox();
                return IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white),
                  tooltip: "Select",
                  onPressed: () => _enterSelectionMode(),
                );
              },
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.notifications.isEmpty) return const SizedBox();
                return IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.white,
                  ),
                  tooltip: "Clear all",
                  onPressed: () => _confirmClearAll(context, provider),
                );
              },
            ),
          ],
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final notifications = provider.notifications;
          final unreadCount = provider.unreadCount;

          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 44,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You're all caught up!\nWe'll notify you when something needs attention.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: provider.refreshNotifications,
            child: CustomScrollView(
              slivers: [
                // Unread count header (hidden while selecting, to keep the
                // selection controls the focus)
                if (unreadCount > 0 && !_selectionMode)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_unread_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: provider.markAllRead,
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Notification list
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notification = notifications[index];
                        final isSelected =
                            _selectedIds.contains(notification.id);

                        return _NotificationCard(
                          notification: notification,
                          selectionMode: _selectionMode,
                          isSelected: isSelected,
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelected(notification.id);
                            } else {
                              provider.markAsRead(notification.id);
                            }
                          },
                          onLongPress: () {
                            if (!_selectionMode) {
                              _enterSelectionMode(notification.id);
                            }
                          },
                          onDismiss: () =>
                              provider.deleteNotification(notification.id),
                        );
                      },
                      childCount: notifications.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDismiss,
  });

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.alert:
        return AppColors.error;
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.info:
        return AppColors.info;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.warning:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.info:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;

    final card = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(isDark ? 0.18 : 0.1)
              : isUnread
                  ? (isDark
                      ? _typeColor.withOpacity(0.08)
                      : _typeColor.withOpacity(0.04))
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : isUnread
                    ? _typeColor.withOpacity(0.25)
                    : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _typeColor.withOpacity(isUnread ? 0.1 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection checkbox (replaces the type icon while selecting)
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 8),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  size: 22,
                ),
              ),
            const SizedBox(width: 8),
            // Type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isUnread && !selectionMode)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: BoxDecoration(
                            color: _typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary
                          .withOpacity(isUnread ? 0.9 : 0.7),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        AppFormatters.formatRelativeTime(
                            notification.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const Spacer(),
                      if (!isUnread)
                        const Text(
                          'Read',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Swipe-to-dismiss stays available for single-item deletion, but is
    // disabled while in selection mode so a swipe doesn't fight with tap
    // selection.
    if (selectionMode) return card;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline,
            color: AppColors.error, size: 24),
      ),
      child: card,
    );
  }
}