import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Loading indicator widget (SmartDrip production-ready)
class LoadingWidget extends StatelessWidget {
  final String? message;
  final bool isOverlay;
  final Color? color;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.isOverlay = false,
    this.color,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primary,
            ),
          ),
        ),

        if (message != null) ...[
          const SizedBox(height: 14),
          Text(
            message!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    // NORMAL LOADING (inline)
    if (!isOverlay) {
      return Center(child: content);
    }

    // OVERLAY LOADING (full screen blocking UI)
    return Material(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 22,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}