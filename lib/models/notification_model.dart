class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;

  final DateTime timestamp;

  final int? soil;
  final double? temperature;
  final double? humidity;

  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.soil,
    this.temperature,
    this.humidity,
    this.isRead = false,
  });

  // ============================================================
  // FROM FIREBASE
  // ============================================================

  factory NotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? firebaseId,
  }) {
    return NotificationModel(
      id: firebaseId ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'SmartDrip Notification',
      message: json['message']?.toString() ?? '',

      type: _parseType(json['type']),

      timestamp: _parseTimestamp(json['timestamp']),

      soil: _parseInt(json['soil']),

      temperature: _parseDouble(json['temperature']),

      humidity: _parseDouble(json['humidity']),

      isRead: json['isRead'] == true,
    );
  }

  // ============================================================
  // TO FIREBASE
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,

      // Firebase-friendly timestamp
      'timestamp': timestamp.millisecondsSinceEpoch,

      'soil': soil,
      'temperature': temperature,
      'humidity': humidity,

      'isRead': isRead,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    int? soil,
    double? temperature,
    double? humidity,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      soil: soil ?? this.soil,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      isRead: isRead ?? this.isRead,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static NotificationType _parseType(dynamic value) {
    final type = value?.toString().toLowerCase();

    switch (type) {
      case 'alert':
        return NotificationType.alert;

      case 'warning':
        return NotificationType.warning;

      case 'success':
        return NotificationType.success;

      case 'info':
        return NotificationType.info;

      default:
        return NotificationType.info;
    }
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    // Firebase ServerValue.timestamp / milliseconds
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    // Also supports ISO timestamp strings
    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }

      final milliseconds = int.tryParse(value);

      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }

    return DateTime.now();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is double) return value.toInt();

    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    return double.tryParse(value.toString());
  }
}

// ============================================================
// NOTIFICATION TYPES
// ============================================================

enum NotificationType {
  alert,
  warning,
  info,
  success,
}