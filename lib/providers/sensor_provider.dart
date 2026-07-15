import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sensor_data.dart';
import '../models/notification_model.dart';
import '../core/services/notification_service.dart'; // adjust path to match your structure

/// Fully client-side alert detection — no Cloud Function, no Blaze plan needed.
/// Works while the app is running (foreground or background), but will NOT
/// fire alerts if the app process is fully closed/killed or the phone reboots.
class SensorProvider extends ChangeNotifier {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('smartdrip/sensor');

  // Writes here so NotificationProvider's listener (smartdrip/notifications)
  // automatically picks up new alerts for the in-app inbox/history.
  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('smartdrip/notifications');

  SensorData? _currentData;
  final List<SensorData> _historicalData = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOnline = false;

  String? _errorMessage;
  DateTime? _lastUpdated;

  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _offlineCheckTimer;

  // ================= ALERT THRESHOLDS =================

  static const double veryDryThreshold = 20.0; // % — matches "Very Dry" UI label
  static const double highTempThreshold = 38.0; // °C
  static const double lowWaterThreshold = 20.0; // %

  // No sensor update within this window = considered offline
  static const Duration offlineThreshold = Duration(minutes: 10);

  // Minimum time between two alerts of the SAME type
  static const Duration _alertCooldown = Duration(minutes: 15);

  // ---- Previous-state tracking (for edge-triggered comparisons) ----
  bool? _prevPumpStatus;
  double? _prevSoil;
  double? _prevTemp;
  double? _prevWaterLevel;
  bool _wasMarkedOffline = false;

  final Map<String, DateTime> _lastAlertTimes = {};

  // ================= GETTERS =================

  SensorData? get currentData => _currentData;

  List<SensorData> get historicalData => List.unmodifiable(_historicalData);

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOnline => _isOnline;

  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  double get moisture => _currentData?.moisture ?? 0.0;
  double get temperature => _currentData?.temperature ?? 0.0;
  double get humidity => _currentData?.humidity ?? 0.0;

  double get currentMoisture => moisture;
  double get currentTemperature => temperature;
  double get currentHumidity => humidity;

  String get moistureStatus {
    if (moisture < 20) return "Very Dry";
    if (moisture < 40) return "Dry";
    if (moisture < 60) return "Optimal";
    if (moisture < 80) return "Moist";
    return "Wet";
  }

  // ================= CONSTRUCTOR =================

  SensorProvider() {
    debugPrint("SensorProvider initialized");
    _startListener();
    _startOfflineWatcher();
    refreshData();
  }

  // ================= FIREBASE LISTENER =================

  void _startListener() {
    _subscription?.cancel();

    _subscription = _ref.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data == null || data is! Map) {
          _currentData = null;
          _isOnline = false;
          _isLoading = false;
          notifyListeners();
          return;
        }

        try {
          final map = Map<dynamic, dynamic>.from(data);
          _processIncomingData(map);
        } catch (e) {
          debugPrint("PARSE ERROR: $e");
          _errorMessage = e.toString();
          _isOnline = false;
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("FIREBASE ERROR: $error");
        _errorMessage = error.toString();
        _isOnline = false;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ================= REFRESH =================

  Future<void> refreshData() async {
    try {
      _isRefreshing = true;
      notifyListeners();

      final snapshot = await _ref.get();
      final data = snapshot.value;

      if (data != null && data is Map) {
        final map = Map<dynamic, dynamic>.from(data);
        _processIncomingData(map);
      }

      _isRefreshing = false;
      notifyListeners();
    } catch (e) {
      debugPrint("REFRESH ERROR: $e");
      _errorMessage = e.toString();
      _isRefreshing = false;
      notifyListeners();
    }
  }

  // ================= CORE PROCESSING =================

  void _processIncomingData(Map<dynamic, dynamic> map) {
    // Use the model's own factory — it already handles the 'soil'/'moisture'
    // key fallback and safe double/timestamp parsing.
    final sensorData = SensorData.fromJson(map).copyWith(
      timestamp: DateTime.now(), // always use local receive time
      isOnline: true,
    );

    final soil = sensorData.moisture;
    final temp = sensorData.temperature;

    // Optional fields — only present if your ESP32 firmware sends them
    final pumpStatus =
        map['pumpStatus'] is bool ? map['pumpStatus'] as bool : null;
    final waterLevel =
        map['waterLevel'] != null ? _safeDouble(map['waterLevel']) : null;

    _currentData = sensorData;
    _isOnline = true;
    _isLoading = false;
    _lastUpdated = DateTime.now();
    _errorMessage = null;

    if (_shouldAddHistory(sensorData)) {
      _historicalData.insert(0, sensorData);
      if (_historicalData.length > 50) {
        _historicalData.removeLast();
      }
    }

    // ---- Reconnect check (device was marked offline, now sending data again) ----
    if (_wasMarkedOffline) {
      _wasMarkedOffline = false;
      _fireAlert(
        type: "DEVICE_RECONNECTED",
        title: "🔋 Device Reconnected",
        message: "SmartDrip device has reconnected.",
      );
    }

    // ---- Pump ON / OFF ----
    if (pumpStatus != null && pumpStatus != _prevPumpStatus) {
      if (pumpStatus == true) {
        _fireAlert(
          type: "PUMP_ON",
          title: "💧 Pump ON (Automatic)",
          message:
              "Soil moisture is low (${soil.toStringAsFixed(0)}%). Irrigation started automatically.",
        );
      } else {
        _fireAlert(
          type: "PUMP_OFF",
          title: "✅ Pump OFF (Automatic)",
          message:
              "Soil moisture reached the target level (${soil.toStringAsFixed(0)}%). Irrigation stopped.",
        );
      }
    }
    if (pumpStatus != null) _prevPumpStatus = pumpStatus;

    // ---- Very Dry Soil (crossing into critical range) ----
    if (soil < veryDryThreshold &&
        (_prevSoil == null || _prevSoil! >= veryDryThreshold)) {
      _fireAlert(
        type: "VERY_DRY",
        title: "⚠️ Very Dry Soil",
        message:
            "Warning: Soil moisture is critically low (${soil.toStringAsFixed(0)}%).",
      );
    }
    _prevSoil = soil;

    // ---- High Temperature (crossing threshold) ----
    if (temp >= highTempThreshold &&
        (_prevTemp == null || _prevTemp! < highTempThreshold)) {
      _fireAlert(
        type: "HIGH_TEMP",
        title: "🌡️ High Temperature",
        message: "Temperature has reached ${temp.toStringAsFixed(0)}°C.",
      );
    }
    _prevTemp = temp;

    // ---- Water Tank Low (only if waterLevel field present) ----
    if (waterLevel != null) {
      if (waterLevel < lowWaterThreshold &&
          (_prevWaterLevel == null || _prevWaterLevel! >= lowWaterThreshold)) {
        _fireAlert(
          type: "LOW_WATER_TANK",
          title: "💦 Water Tank Low",
          message: "Water tank is running low.",
        );
      }
      _prevWaterLevel = waterLevel;
    }

    notifyListeners();
  }

  // ================= OFFLINE WATCHER =================
  // Since this is fully client-side, offline detection only checks while
  // the app is running — it periodically compares "time since last update"
  // against the threshold. It won't detect offline status while the app
  // itself is closed.

  void _startOfflineWatcher() {
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_lastUpdated == null) return;

      final stale = DateTime.now().difference(_lastUpdated!) > offlineThreshold;

      if (stale && !_wasMarkedOffline) {
        _wasMarkedOffline = true;
        _isOnline = false;
        _fireAlert(
          type: "DEVICE_OFFLINE",
          title: "📶 ESP32 Offline",
          message: "SmartDrip device is offline.",
        );
        notifyListeners();
      }
    });
  }

  // ================= ALERT FIRING (with cooldown) =================

  void _fireAlert({
    required String type,
    required String title,
    required String message,
  }) {
    final now = DateTime.now();
    final last = _lastAlertTimes[type];

    if (last != null && now.difference(last) < _alertCooldown) {
      debugPrint("Skipping $type alert: still in cooldown");
      return;
    }

    _lastAlertTimes[type] = now;

    // 1. Local push notification (shows immediately while app is running)
    NotificationService.showNotification(title, message);

    // 2. Save to Firebase so it shows up in the in-app notification
    //    inbox/history via NotificationProvider.
    _saveNotificationRecord(type: type, title: title, message: message);
  }

  Future<void> _saveNotificationRecord({
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      final newRef = _notificationsRef.push();
      final id = newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();

      final model = NotificationModel(
        id: id,
        title: title,
        message: message,
        type: _mapAlertTypeToNotificationType(type),
        timestamp: DateTime.now(),
        isRead: false,
      );

      await newRef.set(model.toJson());
    } catch (e) {
      debugPrint("Failed to save notification record: $e");
    }
  }

  NotificationType _mapAlertTypeToNotificationType(String alertType) {
    switch (alertType) {
      case "PUMP_ON":
        return NotificationType.info;
      case "PUMP_OFF":
        return NotificationType.success;
      case "DEVICE_RECONNECTED":
        return NotificationType.success;
      case "VERY_DRY":
      case "HIGH_TEMP":
      case "LOW_WATER_TANK":
        return NotificationType.warning;
      case "DEVICE_OFFLINE":
        return NotificationType.alert;
      default:
        return NotificationType.info;
    }
  }

  // ================= HELPERS =================

  bool _shouldAddHistory(SensorData data) {
    if (_historicalData.isEmpty) return true;
    final last = _historicalData.first;
    return last.moisture != data.moisture ||
        last.temperature != data.temperature ||
        last.humidity != data.humidity;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    _subscription?.cancel();
    _offlineCheckTimer?.cancel();
    super.dispose();
  }
}