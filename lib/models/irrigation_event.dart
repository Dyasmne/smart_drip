class IrrigationEvent {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;

  final double moistureBefore;
  final double moistureAfter;

  final IrrigationMode mode;
  final IrrigationTrigger triggeredBy;

  final bool isActive;

  const IrrigationEvent({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.moistureBefore,
    required this.moistureAfter,
    required this.mode,
    required this.triggeredBy,
    this.isActive = false,
  });

  // =========================
  // COMPUTED VALUES
  // =========================

  Duration? get duration {
    final end = endTime ?? (isActive ? DateTime.now() : null);
    if (end == null) return null;
    return end.difference(startTime);
  }

  double get moistureChange => moistureAfter - moistureBefore;

  /// For chart intensity (important for graphs 📊)
  double get impactScore =>
      (moistureAfter - moistureBefore).abs().clamp(0, 100);

  String get durationText {
    final d = duration;
    if (d == null) return 'Running...';

    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;

    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  // =========================
  // FIREBASE JSON
  // =========================

  factory IrrigationEvent.fromJson(Map<dynamic, dynamic> json) {
    return IrrigationEvent(
      id: json['id'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      moistureBefore: (json['moistureBefore'] ?? 0).toDouble(),
      moistureAfter: (json['moistureAfter'] ?? 0).toDouble(),
      mode: IrrigationMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => IrrigationMode.manual,
      ),
      triggeredBy: IrrigationTrigger.values.firstWhere(
        (e) => e.name == json['triggeredBy'],
        orElse: () => IrrigationTrigger.user,
      ),
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'moistureBefore': moistureBefore,
      'moistureAfter': moistureAfter,
      'mode': mode.name,
      'triggeredBy': triggeredBy.name,
      'isActive': isActive,
    };
  }

  IrrigationEvent copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? moistureBefore,
    double? moistureAfter,
    IrrigationMode? mode,
    IrrigationTrigger? triggeredBy,
    bool? isActive,
  }) {
    return IrrigationEvent(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      moistureBefore: moistureBefore ?? this.moistureBefore,
      moistureAfter: moistureAfter ?? this.moistureAfter,
      mode: mode ?? this.mode,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      isActive: isActive ?? this.isActive,
    );
  }
}

// =========================
// ENUMS (IMPORTANT UPGRADE)
// =========================

enum IrrigationMode { auto, manual }

enum IrrigationTrigger {
  user,
  autoThreshold,
  schedule,
}
