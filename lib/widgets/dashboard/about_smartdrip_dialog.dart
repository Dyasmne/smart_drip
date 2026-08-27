import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Static "About" dialog for the SmartDrip system.
/// Content sourced from the official capstone documentation
/// (SmartDrip: IoT-Enabled Android-Based Automated Soil Moisture
/// Monitoring and Drip Irrigation Control Framework).
class AboutSmartDripDialog extends StatelessWidget {
  const AboutSmartDripDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AboutSmartDripDialog(),
    );
  }

  static const String _appVersion = "1.0.0";

  static const String _tagline = "Where Technology Meets Agriculture";

  static const String _description =
      "SmartDrip: IoT-Enabled Android-Based Automated Soil Moisture "
      "Monitoring and Drip Irrigation Control System";

  static const List<String> _hardware = [
    "ESP32 Microcontroller",
    "Capacitive Soil Moisture Sensor (v1.2)",
    "DHT11 Temperature & Humidity Sensor",
    "5V Relay Module",
    "Submersible Water Pump",
    "Power Supply",
  ];

  // Reflects what's actually implemented in the app right now — not the
  // thesis's originally proposed FCM push notifications, since the
  // current SensorProvider only fires local (in-app) notifications via
  // flutter_local_notifications. Update this if FCM gets added later.
  static const List<String> _techStack = [
    "Flutter",
    "Firebase Authentication",
    "Firebase Realtime Database",
    "Local Notifications (flutter_local_notifications)",
  ];

  static const List<Map<String, String>> _teamMembers = [
    {"name": "Jonna M. Icawat", "role": "Project Leader"},
    {"name": "Jasmine Rose D. Padilla", "role": "Programmer"},
    {"name": "Rica B. Icaro", "role": "UI/UX Design"},
    {"name": "Robin Quijano", "role": "Technical Writer"},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.info_outline, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "About SmartDrip",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _tagline,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                _description,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              const Text(
                "Hardware Used",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._hardware.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Built With",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._techStack.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Version $_appVersion",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                "Development Team",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._teamMembers.map(
                (member) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: member["name"],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(text: " — ${member["role"]}"),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}