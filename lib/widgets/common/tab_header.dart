import 'package:flutter/material.dart';

import '../../core/constants/soil_zones.dart';

/// Gradient banner header for bottom-nav tab screens (Control, History,
/// Settings). Its color follows the soil zone, same as the Home header
/// and CustomAppBar.
class TabHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const TabHeader({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final zone = SoilZones.currentOf(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: SoilZones.gradient(zone)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actions != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            ),
        ],
      ),
    );
  }
}