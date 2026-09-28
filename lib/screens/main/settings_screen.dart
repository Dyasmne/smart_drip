import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sensor_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/custom_appbar.dart';
import '../../widgets/common/tab_header.dart';
import '../../widgets/dashboard/about_smartdrip_dialog.dart';
import '../../widgets/common/profile_avatar.dart';

class SettingsScreen extends StatelessWidget {
  final bool isTab;
  const SettingsScreen({super.key, this.isTab = false});

  static const Color _brand = Color(0xff123524);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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

            // Provider-level flag: reflects the 10-minute offline watcher.
            final isOnline = sensor.isOnline;

            // Time of the most recent reading from the ESP32.
            final DateTime? lastSeen = sensor.currentData?.timestamp;

            return LayoutBuilder(
              builder: (context, constraints) {
                final hPad = constraints.maxWidth < 360 ? 14.0 : 18.0;

                final content = _buildContent(
                  context: context,
                  theme: theme,
                  isDark: isDark,
                  user: user,
                  appProvider: appProvider,
                  isOnline: isOnline,
                  lastSeen: lastSeen,
                  auth: auth,
                );

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

  // ================= SHARED CONTENT =================
  List<Widget> _buildContent({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required dynamic user,
    required AppProvider appProvider,
    required bool isOnline,
    required DateTime? lastSeen,
    required AuthProvider auth,
  }) {
    final subtle = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final chevron = Icon(
      Icons.chevron_right,
      size: 20,
      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
    );

    return [
      // ================= PROFILE CARD =================
      _GlassCard(
        isDark: isDark,
        child: Row(
          children: [
            ProfileAvatar(
              initials: user?.initials ?? 'U',
              radius: 26,
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
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusPill(isOnline: isOnline),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.memory,
                              size: 13,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                side: BorderSide(color: _brand.withOpacity(0.4)),
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
                  color: _brand,
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
        icon: Icons.schedule_rounded,
        title: "Last Seen",
        subtitle: lastSeen == null
            ? "No data yet"
            : isOnline
                ? "Just now • ${_formatClock(lastSeen)}"
                : "${_relativeTime(lastSeen)} • ${_formatClock(lastSeen)}",
        color: Colors.orange,
      ),

      const SizedBox(height: 10),

      _StatusCard(
        isDark: isDark,
        icon: Icons.developer_board,
        title: "Device ID",
        subtitle: user?.deviceId ?? "Not configured",
        color: Colors.blue,
        onTap: () => _showEditDeviceId(context, auth),
        trailing: chevron,
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
          activeColor: _brand,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Text(
            "Dark Mode",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          secondary: _IconBadge(
            icon: Icons.dark_mode_outlined,
            color: Colors.indigo,
            isDark: isDark,
          ),
        ),
      ),

      const SizedBox(height: 24),

      // ================= ACCOUNT & SUPPORT =================
      _SectionTitle("Account & Support", isDark),

      _GlassCard(
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.lock_reset_rounded,
              color: Colors.teal,
              title: "Change Password",
              subtitle: "Send a reset link to your email",
              isDark: isDark,
              onTap: () => _confirmChangePassword(context, user?.email),
            ),
            _TileDivider(isDark: isDark),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              color: Colors.purple,
              title: "Help & FAQ",
              subtitle: "Common questions about SmartDrip",
              isDark: isDark,
              onTap: () => _showHelp(context),
            ),
            _TileDivider(isDark: isDark),
            _SettingsTile(
              icon: Icons.wifi_password_rounded,
              color: Colors.blue,
              title: "Device WiFi Setup",
              subtitle: "How to connect or reset the ESP32 WiFi",
              isDark: isDark,
              onTap: () => _showWifiGuide(context),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // ================= ABOUT =================
      _SectionTitle("About", isDark),

      _GlassCard(
        isDark: isDark,
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: () => AboutSmartDripDialog.show(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco_outlined, color: _brand, size: 20),
          ),
          title: Text(
            "SmartDrip",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Text(
            "Version ${AppConfig.appVersion} • Tap for details",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          trailing: chevron,
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

  // ================= HELPERS =================
  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hr ago";
    return "${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago";
  }

  static String _formatClock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m $ap";
  }

  // ================= CHANGE PASSWORD =================
  void _confirmChangePassword(BuildContext context, String? email) {
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No email found for this account")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Change Password"),
        content: Text(
          "We'll send a password reset link to\n$email",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brand),
            onPressed: () async {
              Navigator.pop(ctx);
              String message;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                message = "Reset link sent. Check your email.";
              } on FirebaseAuthException catch (e) {
                message = e.message ?? "Could not send reset email";
              } catch (_) {
                message = "Could not send reset email";
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            },
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }

  // ================= HELP & FAQ =================
  void _showHelp(BuildContext context) {
    const faqs = [
      [
        "Why does it say ESP32 is Offline?",
        "The app marks the device offline if no reading arrived in the last "
            "10 minutes. Check that the device has power and is connected to "
            "WiFi.",
      ],
      [
        "How does automatic irrigation work?",
        "When mode is Auto and Automatic Irrigation is enabled, the pump "
            "turns on when soil moisture drops to your low threshold and "
            "turns off at the high threshold.",
      ],
      [
        "Why did I get a push notification?",
        "SmartDrip alerts you when the soil is too dry or too wet, and when "
            "the device goes offline.",
      ],
      [
        "Can I control the pump manually?",
        "Yes. Open the Control tab and switch the pump to Manual, then turn "
            "it on or off. Switch back to Auto to let the system decide.",
      ],
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Help & FAQ"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in faqs) ...[
                  Text(
                    f[0],
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f[1],
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ================= WIFI SETUP GUIDE =================
  void _showWifiGuide(BuildContext context) {
    const steps = [
      "Power on the SmartDrip device.",
      "If it can't connect to a saved WiFi, it opens its own setup "
          "hotspot.",
      "On your phone, connect to that hotspot from your WiFi list.",
      "A setup page opens automatically. If not, open your browser and "
          "go to 192.168.4.1.",
      "Choose your WiFi network, enter the password, and save.",
      "Wait for the device to reconnect. The status here will change to "
          "Online.",
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Device WiFi Setup"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _brand,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${i + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
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
            style: ElevatedButton.styleFrom(backgroundColor: _brand),
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

  // ================= EDIT DEVICE ID =================
  void _showEditDeviceId(BuildContext context, AuthProvider auth) {
    final controller = TextEditingController(text: auth.user?.deviceId ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Device ID"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the ESP32 device ID to pair this account with your "
              "SmartDrip unit.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Device ID",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brand),
            onPressed: () async {
              final newId = controller.text.trim();
              if (newId.isEmpty) return;

              await auth.updateProfile(deviceId: newId);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Device ID updated")),
                );
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

/// Small colored rounded-square icon, same look as the Quick Actions badges.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;

  const _IconBadge({
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: _IconBadge(icon: icon, color: color, isDark: isDark),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  final bool isDark;
  const _TileDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 14,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isOnline;
  const _StatusPill({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}