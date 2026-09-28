class SensorData {
  final double moisture;
  final DateTime timestamp;
  final bool isOnline;

  const SensorData({
    required this.moisture,
    required this.timestamp,
    this.isOnline = false,
  });

  factory SensorData.fromJson(Map<dynamic, dynamic> json) {
    return SensorData(
      moisture: _toDouble(
        json['soil'] ?? json['moisture'],
      ),
      timestamp: _parseTimestamp(
        json['timestamp'],
      ),
      isOnline: json['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soil': moisture,
      'timestamp': timestamp.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  SensorData copyWith({
    double? moisture,
    DateTime? timestamp,
    bool? isOnline,
  }) {
    return SensorData(
      moisture: moisture ?? this.moisture,
      timestamp: timestamp ?? this.timestamp,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return '''
SensorData(
  moisture: $moisture,
  online: $isOnline
)
''';
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;

  if (value is int) {
    return value.toDouble();
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0.0;
}

/// Parses the `timestamp` field coming from Firebase.
///
/// The ESP32 firmware writes this via `epochMillisString()`, which sends a
/// STRING of epoch-millisecond digits (e.g. "1788604195000") — NOT an
/// ISO8601 string. `DateTime.tryParse()` only understands ISO8601, so it
/// was silently failing on every real reading from the device and always
/// falling back to `DateTime.now()`. That's why "Last Update" looked fresh
/// on every app open even when the ESP32 had been offline for hours: the
/// real timestamp from the device was never actually being read.
///
/// Fix: when the value is a String, try parsing it as an integer
/// (epoch millis) FIRST, and only fall back to ISO8601 parsing for values
/// that aren't purely numeric (kept for backward-compat / safety).
DateTime _parseTimestamp(dynamic value) {
  try {
    if (value == null) {
      return DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      // Epoch-millis digit string (what the firmware actually sends).
      final asInt = int.tryParse(value);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }

      // Fallback: ISO8601 string (e.g. from toJson() round-trips).
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}