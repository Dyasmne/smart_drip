import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  DatabaseReference get _sensorRef =>
      _database.ref('smartdrip/sensor');

  DatabaseReference get _pumpRef =>
      _database.ref('smartdrip/pump');

  /// Sensor Stream
  Stream<Map<String, dynamic>> getSensorData() {
    return _sensorRef.onValue.map((event) {
      final snapshot = event.snapshot;

      if (!snapshot.exists || snapshot.value == null) {
        return {
          'soil': 0,
          'temperature': 0.0,
          'humidity': 0,
        };
      }

      final data = Map<dynamic, dynamic>.from(
        snapshot.value as Map,
      );

      return {
        'soil': data['soil'] ?? 0,
        'temperature': (data['temperature'] ?? 0).toDouble(),
        'humidity': data['humidity'] ?? 0,
      };
    });
  }

  /// Pump Stream
  Stream<String> getPumpState() {
    return _pumpRef.onValue.map((event) {
      final snapshot = event.snapshot;

      if (!snapshot.exists || snapshot.value == null) {
        return 'OFF';
      }

      final data = Map<dynamic, dynamic>.from(
        snapshot.value as Map,
      );

      return data['state']?.toString() ?? 'OFF';
    });
  }

  /// Read Sensor Once
  Future<Map<String, dynamic>> fetchSensorData() async {
    final snapshot = await _sensorRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return {
        'soil': 0,
        'temperature': 0.0,
        'humidity': 0,
      };
    }

    final data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );

    return {
      'soil': data['soil'] ?? 0,
      'temperature': (data['temperature'] ?? 0).toDouble(),
      'humidity': data['humidity'] ?? 0,
    };
  }

  /// Read Pump Once
  Future<String> fetchPumpState() async {
    final snapshot = await _pumpRef.get();

    if (!snapshot.exists || snapshot.value == null) {
      return 'OFF';
    }

    final data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );

    return data['state']?.toString() ?? 'OFF';
  }

  /// Control Pump
  Future<void> setPumpState(bool isOn) async {
    await _pumpRef.update({
      'state': isOn ? 'ON' : 'OFF',
    });
  }
}