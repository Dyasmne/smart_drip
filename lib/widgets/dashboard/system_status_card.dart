import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// System mode (Auto / Manual)
enum SystemMode { auto, manual }

/// Card showing system status with IoT support
class SystemStatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  /// UI states
  final SystemMode mode;
  final bool isLocked;
  final bool isActive;

  /// Actions
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final Widget? trailing;

  const SystemStatusCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.mode = SystemMode.auto,
    this.isLocked = false,
    this.isActive = true,
  });

  void _handleTap() {
    if (isLocked) return;
    HapticFeedback.lightImpact();
    onTap?.call();
  }

  void _handleLongPress() {
    if (isLocked) return;
    HapticFeedback.mediumImpact();
    onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final statusColor = isLocked
        ? AppColors.error
        : isActive
            ? color
            : Colors.grey;

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ICON
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),

              const SizedBox(width: 14),

              // TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Mode badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.labelMedium,
                          ),
                        ),
                        _ModeBadge(mode: mode),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      style: AppTextStyles.h4.copyWith(color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // trailing / lock icon
              if (isLocked)
                const Icon(Icons.lock, color: AppColors.error)
              else if (trailing != null)
                trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mode badge (AUTO / MANUAL)
class _ModeBadge extends StatelessWidget {
  final SystemMode mode;

  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final isAuto = mode == SystemMode.auto;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAuto
            ? AppColors.primary.withOpacity(0.12)
            : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAuto ? "AUTO" : "MANUAL",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isAuto ? AppColors.primary : Colors.orange,
        ),
      ),
    );
  }
}

/// Compact info tile for dashboard
class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}