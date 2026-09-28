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

  // ================= EDITABLE CONTENT =================

  static const String _appVersion = "1.0.0";
  static const String _lastUpdated = "September 2026";

  static const String _tagline = "Where Technology Meets Agriculture";

  static const String _description =
      "SmartDrip: IoT-Enabled Android-Based Automated Soil Moisture "
      "Monitoring and Drip Irrigation Control Framework";

  static const String _mission =
      "SmartDrip helps farmers and growers water their crops at the right "
      "time and in the right amount. By monitoring soil moisture in real "
      "time and automating drip irrigation, it reduces manual watering "
      "and helps save water.";

  // (icon, title, subtitle)
  static const List<List<dynamic>> _features = [
    [
      Icons.water_drop_outlined,
      "Real-time Soil Monitoring",
      "Live soil moisture readings from the field",
    ],
    [
      Icons.autorenew_rounded,
      "Automatic & Manual Irrigation",
      "Let the system decide, or control the pump yourself",
    ],
    [
      Icons.notifications_active_outlined,
      "Smart Alerts",
      "Get notified when the soil is too dry or too wet",
    ],
    [
      Icons.history_rounded,
      "Irrigation History",
      "Review every watering event and the moisture behind it",
    ],
  ];

  // (title, subtitle)
  static const List<List<String>> _steps = [
    ["Sense", "The sensor measures soil moisture in the field."],
    ["Decide", "SmartDrip compares it against your set thresholds."],
    ["Water", "The pump turns on or off automatically."],
  ];

  // TODO: palitan ng actual details ng school/program ninyo.
  static const String _school = "Catanduanes State University";
  static const String _program = "BS in Information Technology";
  static const String _academicYear = "A.Y. 2025–2026";
 

  static const List<Map<String, String>> _teamMembers = [
    {"name": "Jonna M. Icawat", "role": "Project Leader"},
    {"name": "Jasmine Rose D. Padilla", "role": "Programmer"},
    {"name": "Rica B. Icaro", "role": "UI Design"},
    {"name": "Robin Quijano", "role": "Documentation"},
  ];

  // ================= BUILD =================

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
              _buildHeader(context),
              const SizedBox(height: 12),
              const Text(
                _description,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),

              // ---------- Purpose ----------
              const SizedBox(height: 18),
              const _SectionHeading("Our Purpose"),
              const SizedBox(height: 6),
              const Text(
                _mission,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),

              // ---------- Key features ----------
              const SizedBox(height: 18),
              const _SectionHeading("Key Features"),
              const SizedBox(height: 8),
              ..._features.map(
                (f) => _FeatureRow(
                  icon: f[0] as IconData,
                  title: f[1] as String,
                  subtitle: f[2] as String,
                ),
              ),

              // ---------- How it works ----------
              const SizedBox(height: 18),
              const _SectionHeading("How It Works"),
              const SizedBox(height: 8),
              for (int i = 0; i < _steps.length; i++)
                _StepRow(
                  number: i + 1,
                  title: _steps[i][0],
                  subtitle: _steps[i][1],
                ),

              // ---------- Version ----------
              const SizedBox(height: 18),
              Text(
                "Version $_appVersion  •  Updated $_lastUpdated",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // ---------- Academic info ----------
              const SizedBox(height: 18),
              const _SectionHeading("Capstone Project"),
              const SizedBox(height: 6),
              const _InfoLine(label: "School", value: _school),
              const _InfoLine(label: "Program", value: _program),
              const _InfoLine(label: "Academic Year", value: _academicYear),
    

              // ---------- Team ----------
              const SizedBox(height: 18),
              const _SectionHeading("Development Team"),
              const SizedBox(height: 4),
              ..._teamMembers.map(
                (member) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
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
              // ---------- Contact + licenses ----------
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text(
                    "Open-source licenses",
                    style: TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () {
                    showLicensePage(
                      context: context,
                      applicationName: "SmartDrip",
                      applicationVersion: _appVersion,
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  "© 2026 SmartDrip. All rights reserved.",
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
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
    );
  }
}

// ================= UI COMPONENTS =================

class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _StepRow extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$number",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: "$title — ",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(text: subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}