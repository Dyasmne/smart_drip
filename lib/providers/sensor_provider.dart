import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/sensor_data.dart';
import '../models/notification_model.dart';
import '../core/services/notification_service.dart';

/// ============================================================
/// SENSOR PROVIDER
/// ============================================================
///
/// Handles:
/// 1. Soil moisture
/// 2. Temperature
/// 3. Humidity
/// 4. Pump ON/OFF monitoring
/// 5. Device offline/reconnected detection
/// 6. Very dry soil alert
/// 7. High temperature alert
/// 8. In-app notification history
///
/// WATER LEVEL IS NOT INCLUDED YET.
/// It can be added later when the water level sensor is installed.
///
/// No Cloud Function.
/// No FCM.
/// Local notifications only while the app is running.
/// ============================================================

class SensorProvider extends ChangeNotifier {
  // ============================================================
  // FIREBASE REFERENCES
  // ============================================================

  final DatabaseReference _sensorRef =
      FirebaseDatabase.instance.ref('smartdrip/sensor');

  final DatabaseReference _pumpRef =
      FirebaseDatabase.instance.ref('smartdrip/pump');

  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('smartdrip/notifications');

  // ============================================================
  // SENSOR DATA
  // ============================================================

  SensorData? _currentData;

  final List<SensorData> _historicalData = [];

  // ============================================================
  // STATUS
  // ============================================================

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOnline = false;

  String? _errorMessage;

  DateTime? _lastUpdated;

  // ============================================================
  // FIREBASE LISTENERS
  // ============================================================

  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _pumpSubscription;

  Timer? _offlineCheckTimer;

  // ============================================================
  // ALERT THRESHOLDS
  // ============================================================

  /// Soil moisture below this = Very Dry
  static const double veryDryThreshold = 20.0;

  /// Temperature at or above this = High Temperature
  static const double highTempThreshold = 38.0;

  /// If no sensor update for 10 minutes = Offline
  static const Duration offlineThreshold =
      Duration(minutes: 10);

  /// Minimum time between alerts of the same type
  static const Duration _alertCooldown =
      Duration(minutes: 15);

  // ============================================================
  // PREVIOUS STATES
  // ============================================================

  bool? _prevPumpStatus;

  double? _prevSoil;

  double? _prevTemp;

  bool _wasMarkedOffline = false;

  // ============================================================
  // ALERT COOLDOWN TRACKING
  // ============================================================

  final Map<String, DateTime> _lastAlertTimes = {};

  // ============================================================
  // GETTERS
  // ============================================================

  SensorData? get currentData => _currentData;

  List<SensorData> get historicalData =>
      List.unmodifiable(_historicalData);

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get isOnline => _isOnline;

  String? get errorMessage => _errorMessage;

  DateTime? get lastUpdated => _lastUpdated;

  // ============================================================
  // SENSOR VALUES
  // ============================================================

  double get moisture =>
      _currentData?.moisture ?? 0.0;

  double get temperature =>
      _currentData?.temperature ?? 0.0;

  double get humidity =>
      _currentData?.humidity ?? 0.0;

  double get currentMoisture => moisture;

  double get currentTemperature => temperature;

  double get currentHumidity => humidity;

  // ============================================================
  // PUMP
  // ============================================================

  bool get pumpStatus =>
      _prevPumpStatus ?? false;

  // ============================================================
  // MOISTURE STATUS
  // ============================================================

  String get moistureStatus {
    if (moisture < 20) {
      return "Very Dry";
    }

    if (moisture < 40) {
      return "Dry";
    }

    if (moisture < 60) {
      return "Optimal";
    }

    if (moisture < 80) {
      return "Moist";
    }

    return "Wet";
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  SensorProvider() {
    debugPrint("SensorProvider initialized");

    _startSensorListener();

    _startPumpListener();

    _startOfflineWatcher();

    refreshData();
  }

  // ============================================================
  // SENSOR FIREBASE LISTENER
  // ============================================================

  void _startSensorListener() {
    _sensorSubscription?.cancel();

    _sensorSubscription = _sensorRef.onValue.listen(
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

          _processSensorData(map);
        } catch (e) {
          debugPrint(
            "Sensor parse error: $e",
          );

          _errorMessage = e.toString();

          _isOnline = false;

          _isLoading = false;

          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint(
          "Firebase sensor error: $error",
        );

        _errorMessage = error.toString();

        _isOnline = false;

        _isLoading = false;

        notifyListeners();
      },
    );
  }

  // ============================================================
  // PUMP FIREBASE LISTENER
  // ============================================================

  /// ESP32 stores pump information here:
  ///
  /// smartdrip
  ///   └── pump
  ///       ├── state: "ON"
  ///       └── mode: "auto"
  ///
  void _startPumpListener() {
    _pumpSubscription?.cancel();

    _pumpSubscription = _pumpRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data == null || data is! Map) {
          return;
        }

        try {
          final map = Map<dynamic, dynamic>.from(data);

          final remoteState =
              map['state']?.toString();

          if (remoteState == null) {
            return;
          }

          final currentPump =
              remoteState.toUpperCase() == "ON";

          // First reading only initializes the state.
          if (_prevPumpStatus == null) {
            _prevPumpStatus = currentPump;

            notifyListeners();

            return;
          }

          // Pump changed
          if (currentPump != _prevPumpStatus) {

            if (currentPump) {
              _fireAlert(
                type: "PUMP_ON",
                title: "💧 Pump ON",
                message:
                    "The irrigation pump has been turned ON.",
              );
            } else {
              _fireAlert(
                type: "PUMP_OFF",
                title: "⛔ Pump OFF",
                message:
                    "The irrigation pump has been turned OFF.",
              );
            }
          }

          _prevPumpStatus = currentPump;

          notifyListeners();
        } catch (e) {
          debugPrint(
            "Pump parse error: $e",
          );
        }
      },
      onError: (error) {
        debugPrint(
          "Firebase pump error: $error",
        );
      },
    );
  }

  // ============================================================
  // PROCESS SENSOR DATA
  // ============================================================

  void _processSensorData(
    Map<dynamic, dynamic> map,
  ) {
    try {
      final sensorData =
          SensorData.fromJson(map).copyWith(
        // Use the time the phone received the data.
        timestamp: DateTime.now(),

        isOnline: true,
      );

      final soil =
          sensorData.moisture;

      final temp =
          sensorData.temperature;

      // --------------------------------------------------------
      // UPDATE CURRENT DATA
      // --------------------------------------------------------

      _currentData = sensorData;

      _isOnline = true;

      _isLoading = false;

      _lastUpdated = DateTime.now();

      _errorMessage = null;

      // --------------------------------------------------------
      // HISTORY
      // --------------------------------------------------------

      if (_shouldAddHistory(sensorData)) {
        _historicalData.insert(
          0,
          sensorData,
        );

        // Keep maximum 50 records
        if (_historicalData.length > 50) {
          _historicalData.removeLast();
        }
      }

      // --------------------------------------------------------
      // DEVICE RECONNECTED
      // --------------------------------------------------------

      if (_wasMarkedOffline) {
        _wasMarkedOffline = false;

        _fireAlert(
          type: "DEVICE_RECONNECTED",
          title: "🔋 Device Reconnected",
          message:
              "SmartDrip device has reconnected.",
        );
      }

      // --------------------------------------------------------
      // VERY DRY SOIL
      // --------------------------------------------------------

      if (
        soil < veryDryThreshold &&
        (
          _prevSoil == null ||
          _prevSoil! >= veryDryThreshold
        )
      ) {
        _fireAlert(
          type: "VERY_DRY",
          title: "⚠️ Very Dry Soil",
          message:
              "Warning: Soil moisture is critically low "
              "(${soil.toStringAsFixed(0)}%).",
        );
      }

      _prevSoil = soil;

      // --------------------------------------------------------
      // HIGH TEMPERATURE
      // --------------------------------------------------------

      if (
        temp >= highTempThreshold &&
        (
          _prevTemp == null ||
          _prevTemp! < highTempThreshold
        )
      ) {
        _fireAlert(
          type: "HIGH_TEMP",
          title: "🌡️ High Temperature",
          message:
              "Temperature has reached "
              "${temp.toStringAsFixed(0)}°C.",
        );
      }

      _prevTemp = temp;

      notifyListeners();
    } catch (e) {
      debugPrint(
        "Sensor processing error: $e",
      );

      _errorMessage = e.toString();

      _isOnline = false;

      _isLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshData() async {
    try {
      _isRefreshing = true;

      _errorMessage = null;

      notifyListeners();

      final snapshot =
          await _sensorRef.get();

      final data =
          snapshot.value;

      if (data != null && data is Map) {
        final map =
            Map<dynamic, dynamic>.from(data);

        _processSensorData(map);
      }

      _isRefreshing = false;

      notifyListeners();
    } catch (e) {
      debugPrint(
        "Refresh error: $e",
      );

      _errorMessage = e.toString();

      _isRefreshing = false;

      notifyListeners();
    }
  }

  // ============================================================
  // OFFLINE WATCHER
  // ============================================================

  /// This works only while the Flutter app is running.
  ///
  /// If the app itself is completely killed,
  /// this timer cannot run.
  void _startOfflineWatcher() {
    _offlineCheckTimer?.cancel();

    _offlineCheckTimer =
        Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (_lastUpdated == null) {
          return;
        }

        final elapsed =
            DateTime.now().difference(
          _lastUpdated!,
        );

        final stale =
            elapsed > offlineThreshold;

        if (stale && !_wasMarkedOffline) {
          _wasMarkedOffline = true;

          _isOnline = false;

          _fireAlert(
            type: "DEVICE_OFFLINE",
            title: "📶 ESP32 Offline",
            message:
                "SmartDrip device is offline.",
          );

          notifyListeners();
        }
      },
    );
  }

  // ============================================================
  // FIRE ALERT
  // ============================================================

  void _fireAlert({
    required String type,
    required String title,
    required String message,
  }) {
    final now =
        DateTime.now();

    final last =
        _lastAlertTimes[type];

    // Prevent duplicate notifications
    if (
      last != null &&
      now.difference(last) <
          _alertCooldown
    ) {
      debugPrint(
        "Skipping $type alert: cooldown active.",
      );

      return;
    }

    _lastAlertTimes[type] = now;

    // ----------------------------------------------------------
    // 1. LOCAL PHONE NOTIFICATION
    // ----------------------------------------------------------

    NotificationService.showNotification(
      title,
      message,
    );

    // ----------------------------------------------------------
    // 2. SAVE TO FIREBASE
    // ----------------------------------------------------------

    _saveNotificationRecord(
      type: type,
      title: title,
      message: message,
    );
  }

  // ============================================================
  // SAVE NOTIFICATION
  // ============================================================

  Future<void> _saveNotificationRecord({
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      final newRef =
          _notificationsRef.push();

      final id =
          newRef.key ??
          DateTime.now()
              .millisecondsSinceEpoch
              .toString();

      final model =
          NotificationModel(
        id: id,
        title: title,
        message: message,
        type:
            _mapAlertTypeToNotificationType(
          type,
        ),
        timestamp: DateTime.now(),
        soil:
            _currentData?.moisture.toInt(),
        temperature:
            _currentData?.temperature,
        humidity:
            _currentData?.humidity,
        isRead: false,
      );

      await newRef.set(
        model.toJson(),
      );
    } catch (e) {
      debugPrint(
        "Failed to save notification: $e",
      );
    }
  }

  // ============================================================
  // ALERT TYPE MAPPING
  // ============================================================

  NotificationType
      _mapAlertTypeToNotificationType(
    String alertType,
  ) {
    switch (alertType) {
      case "PUMP_ON":
        return NotificationType.info;

      case "PUMP_OFF":
        return NotificationType.success;

      case "DEVICE_RECONNECTED":
        return NotificationType.success;

      case "VERY_DRY":
        return NotificationType.warning;

      case "HIGH_TEMP":
        return NotificationType.warning;

      case "DEVICE_OFFLINE":
        return NotificationType.alert;

      default:
        return NotificationType.info;
    }
  }

  // ============================================================
  // HISTORY
  // ============================================================

  bool _shouldAddHistory(
    SensorData data,
  ) {
    if (_historicalData.isEmpty) {
      return true;
    }

    final last =
        _historicalData.first;

    return last.moisture !=
            data.moisture ||
        last.temperature !=
            data.temperature ||
        last.humidity !=
            data.humidity;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _sensorSubscription?.cancel();

    _pumpSubscription?.cancel();

    _offlineCheckTimer?.cancel();

    super.dispose();
  }
}