import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppHelpers {
  AppHelpers._();

  // =========================
  // MOISTURE UI HELPERS
  // =========================

  static Color getMoistureColor(double moisture) {
    final m = moisture.clamp(0, 100);

    if (m < 20) return AppColors.moistureLow;
    if (m < 40) return AppColors.moistureMedium;
    if (m < 70) return AppColors.moistureGood;
    return AppColors.moistureHigh;
  }

  static IconData getMoistureIcon(double moisture) {
    final m = moisture.clamp(0, 100);

    if (m < 20) return Icons.water_drop_outlined;
    if (m < 40) return Icons.water_drop;
    if (m < 70) return Icons.opacity;
    return Icons.water;
  }

  // =========================
  // PUMP STATUS HELPERS (NEW 🔥)
  // =========================

  static Color getPumpColor(String status) {
    return status.toUpperCase() == 'ON' ? Colors.green : Colors.red;
  }

  static IconData getPumpIcon(String status) {
    return status.toUpperCase() == 'ON' ? Icons.power : Icons.power_off;
  }

  // =========================
  // SNACKBAR
  // =========================

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: duration,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =========================
  // CONFIRM DIALOG
  // =========================

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // =========================
  // VALIDATION (IMPROVED)
  // =========================

  static bool isValidEmail(String email) {
    final regex = RegExp(
      r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$',
    );
    return regex.hasMatch(email.trim());
  }

  static bool isValidPassword(String password) {
    // stronger rule (capstone-ready)
    return password.length >= 6 && password.contains(RegExp(r'[0-9]'));
  }

  // =========================
  // GENERAL UX
  // =========================

  static String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
