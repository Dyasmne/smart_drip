import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// SmartDrip AppBar (Firebase + IoT Dashboard ready)
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final Widget? leading;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool useGradient;
  final bool floatingStyle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle = true,
    this.leading,
    this.elevation = 0,
    this.bottom,
    this.useGradient = true,
    this.floatingStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fgColor = foregroundColor ??
        (isDark ? Colors.white : Colors.white);

    final bgColor = backgroundColor ?? AppColors.primary;

    return AppBar(
      title: Text(
        title,
        style: AppTextStyles.h4.copyWith(
          color: fgColor,
          fontSize: 18,
        ),
      ),
      centerTitle: centerTitle,
      elevation: floatingStyle ? 6 : elevation,
      backgroundColor: useGradient ? Colors.transparent : bgColor,
      foregroundColor: fgColor,
      automaticallyImplyLeading: showBackButton,

      leading: leading ??
          (showBackButton && Navigator.canPop(context)
              ? IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                )
              : null),

      actions: actions,

      bottom: bottom,

      flexibleSpace: useGradient
          ? Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}