class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final int? soil;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.soil,
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
      title: json['title']?.toString() ??
          'SmartDrip Notification',
      message: json['message']?.toString() ?? '',
      type: _parseType(json['type']),
      timestamp: _parseTimestamp(json['timestamp']),
      soil: _parseInt(json['soil']),
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
      'timestamp': timestamp.millisecondsSinceEpoch,
      'soil': soil,
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
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      soil: soil ?? this.soil,
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

  // ============================================================
  // TIMESTAMP PARSER
  // ============================================================
  //
  // IMPORTANT:
  // Never use DateTime.now() as a fallback here.
  //
  // If Firebase has no valid timestamp, using DateTime.now()
  // would make an old/invalid notification appear as
  // "Just now".
  //
  // Epoch is used instead so the problem is visible rather
  // than silently creating a fake current timestamp.
  // ============================================================

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    // Firebase timestamp stored as integer
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    // Firebase timestamp stored as double
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
      );
    }

    // ISO timestamp or numeric timestamp stored as String
    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }

      final milliseconds = int.tryParse(value);

      if (milliseconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
        );
      }
    }

    // Invalid timestamp
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // INTEGER PARSER
  // ============================================================

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
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