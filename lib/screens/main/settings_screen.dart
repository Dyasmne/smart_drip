import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/custom_appbar.dart';
import '../../widgets/common/tab_header.dart';

class SettingsScreen extends StatelessWidget {
  final bool isTab;
  const SettingsScreen({super.key, this.isTab = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Same CustomAppBar widget Control/History use for their direct-route
      // header — reusing it (instead of a hand-built gradient Container)
      // guarantees Settings matches them exactly, since it's literally the
      // same component.
      appBar: isTab
          ? null
          : const CustomAppBar(
              title: 'Settings',
              showBackButton: true,
            ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Consumer3<AuthProvider, AppProvider, SensorProvider>(
          builder: (context, auth, appProvider, sensor, _) {
            final user = auth.user;
            final isOnline = sensor.currentData?.isOnline ?? false;

            return LayoutBuilder(
              builder: (context, constraints) {
                // scale horizontal padding relative to screen width
                final hPad = constraints.maxWidth < 360 ? 14.0 : 18.0;

                final content = _buildContent(
                  context: context,
                  theme: theme,
                  isDark: isDark,
                  user: user,
                  appProvider: appProvider,
                  isOnline: isOnline,
                  auth: auth,
                );

                // ================= TAB MODE (bottom nav) =================
                // Gradient banner header, matching Control/History tabs.
                if (isTab) {
                  return Column(
                    children: [
                      const TabHeader(title: "Settings"),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: content,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // ================= DIRECT ROUTE (pushed screen) =================
                // Header is now the Scaffold's CustomAppBar (set above), so
                // the body is just the scrollable content — same structure
                // as ControlScreen's direct-route branch.
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: content,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ================= SHARED CONTENT (cards below header) =================
  List<Widget> _buildContent({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required dynamic user,
    required AppProvider appProvider,
    required bool isOnline,
    required AuthProvider auth,
  }) {
    return [
      // ================= PROFILE CARD =================
      _GlassCard(
        isDark: isDark,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xff123524),
              child: Text(
                user?.initials ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Guest',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user?.email ?? 'No email',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.memory,
                          size: 13,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user?.deviceId ?? 'No device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                side:
                    BorderSide(color: const Color(0xff123524).withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showEditProfile(context, auth),
              child: const Text(
                "Edit",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff123524),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // ================= DEVICE STATUS =================
      _SectionTitle("Device Status", isDark),

      _StatusCard(
        isDark: isDark,
        icon: isOnline ? Icons.wifi : Icons.wifi_off,
        title: "ESP32 Connection",
        subtitle: isOnline ? "Online" : "Offline",
        color: isOnline ? Colors.green : Colors.redAccent,
      ),

      const SizedBox(height: 10),

      _StatusCard(
        isDark: isDark,
        icon: Icons.developer_board,
        title: "Device ID",
        subtitle: user?.deviceId ?? "Not configured",
        color: Colors.blue,
      ),

      const SizedBox(height: 24),

      // ================= PREFERENCES =================
      _SectionTitle("Preferences", isDark),

      _GlassCard(
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: SwitchListTile(
          value: appProvider.isDarkMode,
          onChanged: (_) => appProvider.toggleDarkMode(),
          activeColor: const Color(0xff123524),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Text(
            "Dark Mode",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          secondary: Icon(
            Icons.dark_mode_outlined,
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
          ),
        ),
      ),

      const SizedBox(height: 24),

      // ================= ABOUT =================
      _SectionTitle("About", isDark),

      _GlassCard(
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xff123524).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco_outlined,
                color: Color(0xff123524), size: 20),
          ),
          title: Text(
            "SmartDrip",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            "Version ${AppConfig.appVersion}",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ),
      ),

      const SizedBox(height: 32),

      // ================= LOGOUT =================
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text(
            "Sign Out",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          onPressed: () => _confirmSignOut(context, auth),
        ),
      ),
    ];
  }

  // ================= CONFIRM SIGN OUT =================
  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out?"),
        content: const Text("Are you sure you want to sign out of SmartDrip?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            child: const Text(
              "Sign Out",
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EDIT PROFILE =================
  void _showEditProfile(BuildContext context, AuthProvider auth) {
    final controller = TextEditingController(text: auth.user?.name ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Profile"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Name",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff123524),
            ),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              await auth.updateProfile(name: controller.text.trim());

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

// ================= UI COMPONENTS =================

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}