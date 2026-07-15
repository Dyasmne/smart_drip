import 'package:intl/intl.dart';

/// Utility class for formatting values in the app
class AppFormatters {
  AppFormatters._();

  // =========================
  // DATE & TIME
  // =========================

  static String formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return '${formatDateShort(dateTime)} • ${formatTime(dateTime)}';
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }

    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }

  // =========================
  // SENSOR DATA
  // =========================

  static String formatMoisture(double value) {
    if (value.isNaN || value.isInfinite) return '0.0%';
    return '${value.clamp(0, 100).toStringAsFixed(1)}%';
  }

  static String getMoistureStatus(double moisture) {
    final m = moisture.clamp(0, 100);

    if (m < 20) return 'Very Dry';
    if (m < 40) return 'Dry';
    if (m < 60) return 'Optimal';
    if (m < 80) return 'Moist';
    return 'Saturated';
  }

  static String formatTemperature(double temp) {
    if (temp.isNaN || temp.isInfinite) return '0°C';
    return '${temp.toStringAsFixed(1)}°C';
  }

  static String formatHumidity(double hum) {
    if (hum.isNaN || hum.isInfinite) return '0%';
    return '${hum.toStringAsFixed(1)}%';
  }

  // =========================
  // PUMP STATUS (NEW 🔥)
  // =========================

  static String formatPumpStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ON':
        return 'Pump Running';
      case 'OFF':
        return 'Pump Stopped';
      default:
        return 'Unknown';
    }
  }

  static String pumpLabel(String status) {
    return status.toUpperCase() == 'ON' ? 'ACTIVE' : 'INACTIVE';
  }

  // =========================
  // NUMBERS
  // =========================

  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';

    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;

    if (remaining == 0) return '$minutes min';

    return '$minutes min $remaining sec';
  }
}
