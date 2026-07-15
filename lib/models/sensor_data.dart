class SensorData {
  final double moisture;
  final double temperature;
  final double humidity;
  final DateTime timestamp;
  final bool isOnline;

  const SensorData({
    required this.moisture,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    this.isOnline = false,
  });

  factory SensorData.fromJson(Map<dynamic, dynamic> json) {
    return SensorData(
      moisture: _toDouble(
        json['soil'] ?? json['moisture'],
      ),
      temperature: _toDouble(
        json['temperature'] ?? json['temp'],
      ),
      humidity: _toDouble(
        json['humidity'],
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
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  SensorData copyWith({
    double? moisture,
    double? temperature,
    double? humidity,
    DateTime? timestamp,
    bool? isOnline,
  }) {
    return SensorData(
      moisture: moisture ?? this.moisture,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      timestamp: timestamp ?? this.timestamp,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return '''
SensorData(
  moisture: $moisture,
  temperature: $temperature,
  humidity: $humidity,
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

DateTime _parseTimestamp(dynamic value) {
  try {
    if (value == null) {
      return DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}
