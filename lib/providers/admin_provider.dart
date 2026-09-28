import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AdminProvider extends ChangeNotifier {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref();

  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> _users = {};
  Map<String, dynamic> _activityLogs = {};
  Map<String, dynamic> _irrigationLogs = {};

  dynamic _pumpStatus;
  dynamic _systemStatus;
  dynamic _sensorData;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic> get users => _users;
  Map<String, dynamic> get activityLogs => _activityLogs;
  Map<String, dynamic> get irrigationLogs => _irrigationLogs;

  dynamic get pumpStatus => _pumpStatus;
  dynamic get systemStatus => _systemStatus;
  dynamic get sensorData => _sensorData;

  // ============================================================
  // OVERVIEW
  // ============================================================

  int get totalUsers => _users.length;

  int get totalLogins {
    return _activityLogs.values.where((log) {
      if (log is Map) {
        final action =
            log['action']?.toString().toLowerCase() ?? '';

        return action == 'logged in' ||
            action == 'logged in with google' ||
            action == 'login' ||
            action == 'log in';
      }

      return false;
    }).length;
  }

  int get totalIrrigationEvents =>
      _irrigationLogs.length;

  // ============================================================
  // IRRIGATION MODE
  // ============================================================

  String? _irrigationMode(dynamic log) {
    if (log is! Map) {
      return null;
    }

    // ----------------------------------------------------------
    // ACTION
    // Example:
    // "MANUAL ON"
    // "MANUAL OFF"
    // "AUTO ON"
    // "AUTOMATIC OFF"
    // ----------------------------------------------------------

    final action = log['action'];

    if (action != null) {
      final text =
          action.toString().toLowerCase();

      if (text.contains('manual')) {
        return 'manual';
      }

      if (text.contains('auto')) {
        return 'auto';
      }
    }

    // ----------------------------------------------------------
    // OTHER MODE FIELDS
    // ----------------------------------------------------------

    final raw = log['mode'] ??
        log['type'] ??
        log['irrigationType'] ??
        log['irrigation_type'] ??
        log['source'] ??
        log['triggeredBy'] ??
        log['triggered_by'];

    if (raw != null) {
      final text =
          raw.toString().toLowerCase().trim();

      const autoWords = {
        'auto',
        'automatic',
        'scheduled',
        'schedule',
        'sensor',
        'threshold',
        'system',
        'esp32',
      };

      const manualWords = {
        'manual',
        'user',
        'app',
        'button',
        'override',
        'manual_override',
      };

      if (autoWords.contains(text)) {
        return 'auto';
      }

      if (manualWords.contains(text)) {
        return 'manual';
      }
    }

    // ----------------------------------------------------------
    // BOOLEAN AUTOMATIC FLAG
    // ----------------------------------------------------------

    final boolFlag = log['isAutomatic'] ??
        log['automatic'] ??
        log['isAuto'] ??
        log['auto'];

    if (boolFlag != null) {
      final isAuto = boolFlag is bool
          ? boolFlag
          : boolFlag
              .toString()
              .toLowerCase() ==
              'true';

      return isAuto ? 'auto' : 'manual';
    }

    // ----------------------------------------------------------
    // BOOLEAN MANUAL FLAG
    // ----------------------------------------------------------

    final manualFlag =
        log['isManual'] ?? log['manual'];

    if (manualFlag != null) {
      final isManual = manualFlag is bool
          ? manualFlag
          : manualFlag
              .toString()
              .toLowerCase() ==
              'true';

      return isManual ? 'manual' : 'auto';
    }

    return null;
  }

  int get automaticIrrigationCount {
    return _irrigationLogs.values
        .where(
          (log) =>
              _irrigationMode(log) == 'auto',
        )
        .length;
  }

  int get manualIrrigationCount {
    return _irrigationLogs.values
        .where(
          (log) =>
              _irrigationMode(log) == 'manual',
        )
        .length;
  }

  int get unclassifiedIrrigationCount {
    return _irrigationLogs.values
        .where(
          (log) =>
              _irrigationMode(log) == null,
        )
        .length;
  }

  // ============================================================
  // SOIL MOISTURE ANALYTICS
  // ============================================================

  List<Map<String, dynamic>>
      get soilMoistureData {
    final data =
        <Map<String, dynamic>>[];

    for (final entry
        in _irrigationLogs.entries) {
      final log = entry.value;

      if (log is Map) {
        final moisture = _toDouble(
          log['soilMoisture'] ??
              log['soil_moisture'] ??
              log['soil'] ??
              log['moisture'],
        );

        final timestamp =
            _readTimestamp(log);

        if (moisture != null &&
            timestamp != null) {
          data.add({
            'moisture': moisture,
            'timestamp': timestamp,
          });
        }
      }
    }

    data.sort(
      (a, b) => a['timestamp']
          .toString()
          .compareTo(
            b['timestamp'].toString(),
          ),
    );

    return data;
  }

  // ============================================================
  // PUMP USAGE
  // ============================================================

  int get pumpOnCount {
    return _activityLogs.values
        .where((log) {
      if (log is Map) {
        final action = log['action']
            ?.toString()
            .toLowerCase();

        return action == 'pump_on' ||
            action == 'pump on';
      }

      return false;
    }).length;
  }

  int get pumpOffCount {
    return _activityLogs.values
        .where((log) {
      if (log is Map) {
        final action = log['action']
            ?.toString()
            .toLowerCase();

        return action == 'pump_off' ||
            action == 'pump off';
      }

      return false;
    }).length;
  }

  // ============================================================
  // USER ACTIVITY
  // ============================================================

  int get registrationCount {
    return _activityLogs.values
        .where((log) {
      if (log is Map) {
        final action = log['action']
            ?.toString()
            .toLowerCase();

        return action == 'registered' ||
            action == 'register';
      }

      return false;
    }).length;
  }

  int get settingsChangeCount {
    return _activityLogs.values
        .where((log) {
      if (log is Map) {
        final action = log['action']
            ?.toString()
            .toLowerCase();

        return action ==
                'settings_changed' ||
            action == 'settings changed';
      }

      return false;
    }).length;
  }

  // ============================================================
  // IRRIGATION EVENTS BY DATE
  // ============================================================

  Map<String, int>
      get irrigationEventsByDate {
    final result =
        <String, int>{};

    for (final log
        in _irrigationLogs.values) {
      if (log is Map) {
        final timestamp =
            _readTimestamp(log);

        if (timestamp == null) {
          continue;
        }

        final date =
            _extractDate(timestamp);

        result[date] =
            (result[date] ?? 0) + 1;
      }
    }

    return result;
  }

  // ============================================================
  // ACTIVITY SUMMARY
  // ============================================================

  Map<String, int> get activitySummary {
    final result =
        <String, int>{};

    for (final log
        in _activityLogs.values) {
      if (log is Map) {
        final action =
            log['action']?.toString() ??
                'Unknown';

        result[action] =
            (result[action] ?? 0) + 1;
      }
    }

    return result;
  }

  // ============================================================
  // LOAD ADMIN DATA
  // ============================================================

  Future<void> loadAdminData() async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      // --------------------------------------------------------
      // USERS
      // --------------------------------------------------------

      final usersSnapshot =
          await _database
              .child('smartdrip/users')
              .get();

      // --------------------------------------------------------
      // ACTIVITY LOGS
      // --------------------------------------------------------

      final activitySnapshot =
          await _database
              .child('smartdrip/activity_logs')
              .get();

      // --------------------------------------------------------
      // IRRIGATION LOGS
      // --------------------------------------------------------

      final irrigationSnapshot =
          await _database
              .child(
                'smartdrip/irrigation_logs',
              )
              .get();

      // --------------------------------------------------------
      // PUMP
      // --------------------------------------------------------

      final pumpSnapshot =
          await _database
              .child('smartdrip/pump')
              .get();

      // --------------------------------------------------------
      // SYSTEM
      // --------------------------------------------------------

      final systemSnapshot =
          await _database
              .child('smartdrip/system')
              .get();

      // --------------------------------------------------------
      // SENSOR
      // --------------------------------------------------------

      final sensorSnapshot =
          await _database
              .child('smartdrip/sensor')
              .get();

      // --------------------------------------------------------
      // STORE DATA
      // --------------------------------------------------------

      _users =
          _convertToMap(
        usersSnapshot.value,
      );

      _activityLogs =
          _convertToMap(
        activitySnapshot.value,
      );

      _irrigationLogs =
          _convertToMap(
        irrigationSnapshot.value,
      );

      _pumpStatus =
          pumpSnapshot.value;

      _systemStatus =
          systemSnapshot.value;

      _sensorData =
          sensorSnapshot.value;

    } catch (e) {
      _error =
          'Failed to load admin data: $e';
    }

    _isLoading = false;

    notifyListeners();
  }

  // ============================================================
  // SYSTEM STATUS
  // ============================================================

  /// Returns true when the SmartDrip system is considered online.
  ///
  /// Your current Firebase structure contains:
  ///
  /// system
  /// ├── autoIrrigation
  /// ├── highThreshold
  /// ├── lowThreshold
  /// ├── mode
  /// ├── pump
  /// └── timestamp
  ///
  /// Since there is currently no explicit "status" field,
  /// the timestamp is used as the fallback.
  bool get isSystemOnline {
    return _systemIsOnline(
      _systemStatus,
    );
  }

  /// User-friendly system status.
  String get systemStatusLabel {
    if (_systemStatus == null) {
      return 'No data';
    }

    if (_systemIsOnline(_systemStatus)) {
      return 'Online';
    }

    if (_systemStatus is Map &&
        _systemStatus.isNotEmpty) {
      return 'Offline';
    }

    return 'No data';
  }

  // ============================================================
  // SYSTEM ONLINE CHECK
  // ============================================================

  bool _systemIsOnline(
    dynamic system,
  ) {
    if (system == null) {
      return false;
    }

    // ----------------------------------------------------------
    // Explicit status/state/online
    // ----------------------------------------------------------

    if (system is Map) {
      final status =
          system['status'] ??
          system['state'] ??
          system['online'];

      if (status != null) {
        if (status is bool) {
          return status;
        }

        final text =
            status
                .toString()
                .toLowerCase()
                .trim();

        return text == 'online' ||
            text == 'true' ||
            text == 'on';
      }

      // --------------------------------------------------------
      // Timestamp fallback
      // --------------------------------------------------------

      final timestamp =
          system['timestamp'];

      if (timestamp != null) {
        final timestampMs =
            _timestampToMilliseconds(
          timestamp,
        );

        if (timestampMs != null) {
          final lastUpdate =
              DateTime.fromMillisecondsSinceEpoch(
            timestampMs,
          );

          final now =
              DateTime.now();

          final difference =
              now.difference(lastUpdate);

          // Allow a small future clock difference.
          if (difference.inSeconds < -30) {
            return true;
          }

          // Consider online when the system has updated
          // within the last 2 minutes.
          return difference.inSeconds <=
              120;
        }
      }
    }

    return false;
  }

  // ============================================================
  // TIMESTAMP TO MILLISECONDS
  // ============================================================

  int? _timestampToMilliseconds(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final text =
        value.toString().trim();

    // Epoch timestamp
    final number =
        int.tryParse(text);

    if (number != null) {
      // 10 digits = seconds
      if (text.length <= 10) {
        return number * 1000;
      }

      // 13 digits = milliseconds
      return number;
    }

    // ISO timestamp
    final parsed =
        DateTime.tryParse(text);

    if (parsed != null) {
      return parsed
          .millisecondsSinceEpoch;
    }

    return null;
  }

  // ============================================================
  // MAP CONVERSION
  // ============================================================

  Map<String, dynamic> _convertToMap(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        ),
      );
    }

    return {};
  }

  // ============================================================
  // DOUBLE CONVERSION
  // ============================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // READ TIMESTAMP
  // ============================================================

  String? _readTimestamp(
    Map log,
  ) {
    final raw =
        log['timestamp'] ??
        log['time'] ??
        log['date'] ??
        log['createdAt'] ??
        log['recordedAt'] ??
        log['lastUpdated'] ??
        log['updatedAt'];

    if (raw == null) {
      return null;
    }

    // ----------------------------------------------------------
    // Integer timestamp
    // ----------------------------------------------------------

    if (raw is int) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        raw,
      )
          .toIso8601String();
    }

    // ----------------------------------------------------------
    // Numeric timestamp
    // ----------------------------------------------------------

    if (raw is num) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        raw.toInt(),
      )
          .toIso8601String();
    }

    final text =
        raw.toString();

    // ----------------------------------------------------------
    // String timestamp containing epoch
    // ----------------------------------------------------------

    final asMillis =
        int.tryParse(text);

    if (asMillis != null &&
        text.length >= 10) {
      final millis =
          text.length <= 10
              ? asMillis * 1000
              : asMillis;

      return DateTime
          .fromMillisecondsSinceEpoch(
        millis,
      )
          .toIso8601String();
    }

    // ----------------------------------------------------------
    // ISO date string
    // ----------------------------------------------------------

    return text;
  }

  // ============================================================
  // EXTRACT DATE
  // ============================================================

  String _extractDate(
    String timestamp,
  ) {
    if (timestamp.length >= 10) {
      return timestamp.substring(0, 10);
    }

    return timestamp;
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    _error = null;

    notifyListeners();
  }
}