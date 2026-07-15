import 'package:firebase_database/firebase_database.dart';
import '../../models/sensor_data.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final DatabaseReference _ref = FirebaseDatabase.instance.ref("smartdrip");

  /// STREAM real-time sensor data
  Stream<SensorData> streamSensorData() {
    return _ref.onValue.map((event) {
      final data = event.snapshot.value as Map?;

      return SensorData(
        moisture: (data?['soil'] ?? 0).toDouble(),
        temperature: (data?['temp'] ?? 0).toDouble(),
        humidity: (data?['humidity'] ?? 0).toDouble(),
        timestamp: DateTime.now(),
        isOnline: data != null,
      );
    });
  }

  /// CONTROL pump (write to Firebase)
  Future<void> setPumpState(bool isOn) async {
    await _ref.update({
      "pump": isOn ? "ON" : "OFF",
    });
  }

  /// Set irrigation mode (optional future use)
  Future<void> setIrrigationMode(String mode) async {
    await _ref.update({
      "mode": mode,
    });
  }

  /// Manual refresh (optional)
  Future<SensorData> getOnce() async {
    final snapshot = await _ref.get();
    final data = snapshot.value as Map?;

    return SensorData(
      moisture: (data?['soil'] ?? 0).toDouble(),
      temperature: (data?['temp'] ?? 0).toDouble(),
      humidity: (data?['humidity'] ?? 0).toDouble(),
      timestamp: DateTime.now(),
      isOnline: data != null,
    );
  }
}
