import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/soil_zones.dart';

/// SmartDrip AppBar. The banner color follows the soil zone (same as the
/// Home header) so every screen looks the same.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  /// Only used when [useGradient] is false AND [zoneAware] is false.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final Widget? leading;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool useGradient;
  final bool floatingStyle;

  /// Set to false for screens that should keep the fixed green look
  /// (login, onboarding, etc.).
  final bool zoneAware;

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
    this.zoneAware = true,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = foregroundColor ?? Colors.white;

    final zone = zoneAware ? SoilZones.currentOf(context) : null;
    final gradientColors = zone != null
        ? SoilZones.gradient(zone)
        : AppColors.primaryGradient.colors;
    final solidColor = zone != null
        ? SoilZones.gradient(zone).first
        : (backgroundColor ?? AppColors.primary);

    return AppBar(
      title: Text(
        title,
        style: AppTextStyles.h4.copyWith(color: fgColor, fontSize: 18),
      ),
      centerTitle: centerTitle,
      elevation: floatingStyle ? 6 : elevation,
      backgroundColor: solidColor,
      foregroundColor: fgColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}