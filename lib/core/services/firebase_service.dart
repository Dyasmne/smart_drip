import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // ============================================================
  // REFERENCES
  // ============================================================

  DatabaseReference get _sensorRef =>
      _database.ref('smartdrip/sensor');

  DatabaseReference get _pumpRef =>
      _database.ref('smartdrip/pump');

  DatabaseReference get _systemRef =>
      _database.ref('smartdrip/system');

  DatabaseReference get _logsRef =>
      _database.ref('smartdrip/irrigation_logs');

  // ============================================================
  // SENSOR STREAM
  // ============================================================

  Stream<Map<String, dynamic>> getSensorData() {
    return _sensorRef.onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null) {
        return {
          'soil': 0,
        };
      }

      if (value is Map) {
        return {
          'soil': value['soil'] ?? 0,
        };
      }

      return {
        'soil': 0,
      };
    });
  }

  // ============================================================
  // SENSOR - READ ONCE
  // ============================================================

  Future<Map<String, dynamic>> fetchSensorData() async {
    final snapshot = await _sensorRef.get();

    final value = snapshot.value;

    if (value == null) {
      return {
        'soil': 0,
      };
    }

    if (value is Map) {
      return {
        'soil': value['soil'] ?? 0,
      };
    }

    return {
      'soil': 0,
    };
  }

  // ============================================================
  // PUMP STREAM
  //
  // Supports both:
  //
  // pump: "ON"
  //
  // and:
  //
  // pump:
  //   state: "ON"
  // ============================================================

  Stream<String> getPumpState() {
    return _pumpRef.onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null) {
        return 'OFF';
      }

      // Current Firebase structure:
      // pump: "ON" / "OFF"
      if (value is String) {
        return value.toUpperCase();
      }

      // Alternative structure:
      // pump: { state: "ON" }
      if (value is Map) {
        final state = value['state'];

        if (state != null) {
          return state.toString().toUpperCase();
        }
      }

      return 'OFF';
    });
  }

  // ============================================================
  // PUMP - READ ONCE
  // ============================================================

  Future<String> fetchPumpState() async {
    final snapshot = await _pumpRef.get();

    final value = snapshot.value;

    if (value == null) {
      return 'OFF';
    }

    if (value is String) {
      return value.toUpperCase();
    }

    if (value is Map) {
      final state = value['state'];

      if (state != null) {
        return state.toString().toUpperCase();
      }
    }

    return 'OFF';
  }

  // ============================================================
  // CONTROL PUMP
  // ============================================================

  Future<void> setPumpState(bool isOn) async {
    await _pumpRef.set(
      isOn ? 'ON' : 'OFF',
    );
  }

  // ============================================================
  // SYSTEM STREAM
  // ============================================================

  Stream<Map<String, dynamic>> getSystemData() {
    return _systemRef.onValue.map((event) {
      final value = event.snapshot.value;

      if (value == null) {
        return <String, dynamic>{};
      }

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

      return <String, dynamic>{};
    });
  }

  // ============================================================
  // SYSTEM - READ ONCE
  // ============================================================

  Future<Map<String, dynamic>> fetchSystemData() async {
    final snapshot = await _systemRef.get();

    final value = snapshot.value;

    if (value == null) {
      return {};
    }

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
  // UPDATE SYSTEM STATUS
  // ============================================================

  Future<void> setSystemOnline(bool online) async {
    await _systemRef.update({
      'status': online ? 'online' : 'offline',
      'timestamp': DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
    });
  }

  // ============================================================
  // UPDATE SYSTEM DATA
  // ============================================================

  Future<void> updateSystemData({
    bool? autoIrrigation,
    int? highThreshold,
    int? lowThreshold,
    String? mode,
    String? pump,
  }) async {
    final Map<String, dynamic> updates = {};

    if (autoIrrigation != null) {
      updates['autoIrrigation'] = autoIrrigation;
    }

    if (highThreshold != null) {
      updates['highThreshold'] = highThreshold;
    }

    if (lowThreshold != null) {
      updates['lowThreshold'] = lowThreshold;
    }

    if (mode != null) {
      updates['mode'] = mode;
    }

    if (pump != null) {
      updates['pump'] = pump;
    }

    updates['timestamp'] =
        DateTime.now().millisecondsSinceEpoch.toString();

    await _systemRef.update(updates);
  }

  // ============================================================
  // IRRIGATION LOGS
  // ============================================================

  Stream<DatabaseEvent> getIrrigationLogs() {
    return _logsRef.onValue;
  }

  // ============================================================
  // IRRIGATION LOGS - READ ONCE
  // ============================================================

  Future<DataSnapshot> fetchIrrigationLogs() async {
    return await _logsRef.get();
  }
}