import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensor_data.dart';
import '../models/notification_model.dart';
import '../core/services/notification_service.dart';

/// ============================================================
/// SENSOR PROVIDER
/// ============================================================
///
/// Handles:
/// 1. Soil moisture
/// 2. Pump ON/OFF + AUTO/MANUAL monitoring
/// 3. Device offline/reconnected detection
/// 4. Very dry soil alert
/// 5. In-app notification history
/// 6. Irrigation thresholds (for the chart's threshold lines)
///
/// WATER LEVEL IS NOT INCLUDED YET.
///
/// No Cloud Function.
/// No FCM here (push notifications for when the app is fully closed
/// are handled separately by the Cloudflare Worker relay).
/// ============================================================

class SensorProvider extends ChangeNotifier {
  // ============================================================
  // FIREBASE REFERENCES
  // ============================================================

  final DatabaseReference _sensorRef =
      FirebaseDatabase.instance.ref('smartdrip/sensor');

  final DatabaseReference _pumpRef =
      FirebaseDatabase.instance.ref('smartdrip/pump');

  final DatabaseReference _settingsRef =
      FirebaseDatabase.instance.ref('smartdrip/settings');

  final DatabaseReference _notificationsRef =
      FirebaseDatabase.instance.ref('smartdrip/notifications');

  // ============================================================
  // SENSOR DATA
  // ============================================================

  SensorData? _currentData;

  /// Committed history points (newest first), sampled every
  /// [historySampleInterval].
  final List<SensorData> _historicalData = [];

  /// The most recent live reading. It is NOT committed to history on
  /// every tick, but the chart always draws it as the last point, so
  /// the line reaches "now" and is visible right after the screen opens
  /// (a chart needs at least 2 points to draw a line).
  SensorData? _livePoint;

  // ============================================================
  // STATUS
  // ============================================================

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isOnline = false;

  String? _errorMessage;

  DateTime? _lastUpdated;

  // ============================================================
  // PUMP MODE + THRESHOLDS (from Firebase)
  // ============================================================

  String? _pumpMode; // "AUTO" / "MANUAL"

  double? _lowThreshold;
  double? _highThreshold;

  // ============================================================
  // FIREBASE LISTENERS
  // ============================================================

  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _pumpSubscription;
  StreamSubscription<DatabaseEvent>? _settingsSubscription;

  Timer? _offlineCheckTimer;

  // ============================================================
  // ALERT THRESHOLDS
  // ============================================================

  /// Soil moisture below this = Very Dry
  static const double veryDryThreshold = 20.0;

  /// If no sensor update for 10 minutes = Offline.
  /// Also used as the "is this incoming data actually fresh" check.
  static const Duration offlineThreshold = Duration(minutes: 10);

  /// Minimum time between alerts of the same type
  static const Duration _alertCooldown = Duration(minutes: 15);

  /// How much real time must pass before a reading is COMMITTED to
  /// _historicalData.
  ///   window ≈ historySampleInterval × _maxHistoryRecords
  ///   e.g. 5 min × 50 = ~4 hours
  static const Duration historySampleInterval = Duration(minutes: 5);

  static const int _maxHistoryRecords = 50;

  // ============================================================
  // PERSISTED ALERT COOLDOWN STATE
  // ============================================================

  static const _prefsLastAlertTimesKey = 'smartdrip_last_alert_times';
  static const _prefsWasOfflineKey = 'smartdrip_was_marked_offline';

  SharedPreferences? _prefs;

  // ============================================================
  // PREVIOUS STATES
  // ============================================================

  bool? _prevPumpStatus;

  double? _prevSoil;

  bool _wasMarkedOffline = false;

  // ============================================================
  // ALERT COOLDOWN TRACKING
  // ============================================================

  final Map<String, DateTime> _lastAlertTimes = {};

  // ============================================================
  // GETTERS
  // ============================================================

  SensorData? get currentData => _currentData;

  /// Committed history only (newest first).
  List<SensorData> get historicalData =>
      List.unmodifiable(_historicalData);

  /// What the chart should draw (newest first): committed history
  /// plus the live point if it is newer than the last committed one.
  List<SensorData> get chartData {
    final list = List<SensorData>.of(_historicalData);
    final live = _livePoint;

    if (live != null &&
        (list.isEmpty || live.timestamp.isAfter(list.first.timestamp))) {
      list.insert(0, live);
    }

    return List.unmodifiable(list);
  }

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  bool get isOnline => _isOnline;

  String? get errorMessage => _errorMessage;

  DateTime? get lastUpdated => _lastUpdated;

  /// "AUTO" / "MANUAL" / null if unknown
  String? get pumpMode => _pumpMode;

  /// From smartdrip/settings/lowThreshold (null until loaded)
  double? get lowThreshold => _lowThreshold;

  /// From smartdrip/settings/highThreshold (null until loaded)
  double? get highThreshold => _highThreshold;

  // ============================================================
  // SOIL MOISTURE
  // ============================================================

  double get moisture => _currentData?.moisture ?? 0.0;

  double get currentMoisture => moisture;

  // ============================================================
  // PUMP
  // ============================================================

  bool get pumpStatus => _prevPumpStatus ?? false;

  // ============================================================
  // MOISTURE STATUS
  // ============================================================
  //
  // Same zones as the guide on the Monitoring screen:
  //   Very Dry 0-20 | Dry 20-40 | Good 40-70 | Wet 70-100

  String get moistureStatus {
    if (moisture < 20) {
      return "Very Dry";
    }

    if (moisture < 40) {
      return "Dry";
    }

    if (moisture < 70) {
      return "Good";
    }

    return "Wet";
  }

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  SensorProvider() {
    debugPrint("SensorProvider initialized");

    _init();
  }

  Future<void> _init() async {
    await _loadPersistedAlertState();

    _startSensorListener();
    _startPumpListener();
    _startSettingsListener();
    _startOfflineWatcher();
  }

  // ============================================================
  // PERSISTED ALERT STATE (load / save)
  // ============================================================

  Future<void> _loadPersistedAlertState() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final raw = _prefs?.getString(_prefsLastAlertTimesKey);

      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;

        decoded.forEach((key, value) {
          final parsed = DateTime.tryParse(value.toString());

          if (parsed != null) {
            _lastAlertTimes[key] = parsed;
          }
        });
      }

      _wasMarkedOffline = _prefs?.getBool(_prefsWasOfflineKey) ?? false;
    } catch (e) {
      debugPrint("Failed to load persisted alert state: $e");
    }
  }

  void _persistLastAlertTimes() {
    final encoded = jsonEncode(
      _lastAlertTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    );

    _prefs?.setString(_prefsLastAlertTimesKey, encoded);
  }

  void _persistWasMarkedOffline() {
    _prefs?.setBool(_prefsWasOfflineKey, _wasMarkedOffline);
  }

  // ============================================================
  // IS THIS DATA ACTUALLY FRESH?
  // ============================================================
  //
  // Firebase keeps the ESP32's last written value even when the
  // device is offline, so "data arrived" != "device is online".
  bool _isDataFresh(DateTime timestamp) {
    return DateTime.now().difference(timestamp) <= offlineThreshold;
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
          // Do NOT clear _currentData / history here. Only flip the
          // online flag; the last known reading stays visible.
          _isOnline = false;
          _isLoading = false;

          notifyListeners();
          return;
        }

        try {
          final map = Map<dynamic, dynamic>.from(data);

          _processSensorData(map);
        } catch (e) {
          debugPrint("Sensor parse error: $e");

          _errorMessage = e.toString();
          _isOnline = false;
          _isLoading = false;

          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("Firebase sensor error: $error");

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

          final remoteMode = map['mode']?.toString();

          if (remoteMode != null && remoteMode.isNotEmpty) {
            _pumpMode = remoteMode.toUpperCase();
          }

          final remoteState = map['state']?.toString();

          if (remoteState == null) {
            notifyListeners();
            return;
          }

          final currentPump = remoteState.toUpperCase() == "ON";

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
                message: "The irrigation pump has been turned ON.",
              );
            } else {
              _fireAlert(
                type: "PUMP_OFF",
                title: "⛔ Pump OFF",
                message: "The irrigation pump has been turned OFF.",
              );
            }
          }

          _prevPumpStatus = currentPump;

          notifyListeners();
        } catch (e) {
          debugPrint("Pump parse error: $e");
        }
      },
      onError: (error) {
        debugPrint("Firebase pump error: $error");
      },
    );
  }

  // ============================================================
  // SETTINGS LISTENER (thresholds only)
  // ============================================================
  ///
  /// smartdrip/settings = { lowThreshold, highThreshold, autoIrrigation }
  ///
  void _startSettingsListener() {
    _settingsSubscription?.cancel();

    _settingsSubscription = _settingsRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data == null || data is! Map) {
          return;
        }

        final map = Map<dynamic, dynamic>.from(data);

        final low = num.tryParse(map['lowThreshold']?.toString() ?? '');
        final high = num.tryParse(map['highThreshold']?.toString() ?? '');

        _lowThreshold = low?.toDouble();
        _highThreshold = high?.toDouble();

        notifyListeners();
      },
      onError: (error) {
        debugPrint("Firebase settings error: $error");
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
      final sensorData = SensorData.fromJson(map);

      final soil = sensorData.moisture;

      final isFresh = _isDataFresh(sensorData.timestamp);

      // --------------------------------------------------------
      // UPDATE CURRENT DATA
      // --------------------------------------------------------

      _currentData = sensorData.copyWith(isOnline: isFresh);

      _livePoint = sensorData;

      _isOnline = isFresh;

      _isLoading = false;

      _lastUpdated = sensorData.timestamp;

      _errorMessage = null;

      // --------------------------------------------------------
      // HISTORY (committed every historySampleInterval)
      // --------------------------------------------------------

      if (_shouldAddHistory(sensorData)) {
        _historicalData.insert(
          0,
          sensorData,
        );

        if (_historicalData.length > _maxHistoryRecords) {
          _historicalData.removeLast();
        }
      }

      // --------------------------------------------------------
      // DEVICE RECONNECTED (only when data is actually fresh)
      // --------------------------------------------------------

      if (_wasMarkedOffline && isFresh) {
        _wasMarkedOffline = false;
        _persistWasMarkedOffline();

        _fireAlert(
          type: "DEVICE_RECONNECTED",
          title: "🔋 Device Reconnected",
          message: "SmartDrip device has reconnected.",
        );
      }

      // --------------------------------------------------------
      // VERY DRY SOIL (also gated on freshness)
      // --------------------------------------------------------

      if (isFresh &&
          soil < veryDryThreshold &&
          (_prevSoil == null || _prevSoil! >= veryDryThreshold)) {
        _fireAlert(
          type: "VERY_DRY",
          title: "⚠️ Very Dry Soil",
          message: "Warning: Soil moisture is critically low "
              "(${soil.toStringAsFixed(0)}%).",
        );
      }

      _prevSoil = soil;

      notifyListeners();
    } catch (e) {
      debugPrint("Sensor processing error: $e");

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

      final snapshot = await _sensorRef.get();

      final data = snapshot.value;

      if (data != null && data is Map) {
        final map = Map<dynamic, dynamic>.from(data);

        _processSensorData(map);
      } else {
        _isOnline = false;
      }

      _isRefreshing = false;

      notifyListeners();
    } catch (e) {
      debugPrint("Refresh error: $e");

      _errorMessage = e.toString();

      _isRefreshing = false;

      notifyListeners();
    }
  }

  // ============================================================
  // OFFLINE WATCHER
  // ============================================================
  ///
  /// Works only while the Flutter app is running. When the app is
  /// fully closed, the Cloudflare Worker cron watchdog covers this.
  void _startOfflineWatcher() {
    _offlineCheckTimer?.cancel();

    _offlineCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (_lastUpdated == null) {
          return;
        }

        final elapsed = DateTime.now().difference(
          _lastUpdated!,
        );

        final stale = elapsed > offlineThreshold;

        if (stale && !_wasMarkedOffline) {
          _wasMarkedOffline = true;
          _persistWasMarkedOffline();

          _isOnline = false;

          _fireAlert(
            type: "DEVICE_OFFLINE",
            title: "📶 ESP32 Offline",
            message: "SmartDrip device is offline.",
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
    final now = DateTime.now();

    final last = _lastAlertTimes[type];

    if (last != null && now.difference(last) < _alertCooldown) {
      debugPrint(
        "Skipping $type alert: cooldown active.",
      );

      return;
    }

    _lastAlertTimes[type] = now;
    _persistLastAlertTimes();

    // 1. LOCAL PHONE NOTIFICATION
    NotificationService.showNotification(
      title,
      message,
    );

    // 2. SAVE TO FIREBASE
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
      final newRef = _notificationsRef.push();

      final id = newRef.key ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final model = NotificationModel(
        id: id,
        title: title,
        message: message,
        type: _mapAlertTypeToNotificationType(type),
        timestamp: DateTime.now(),
        soil: _currentData?.moisture.toInt(),
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

  NotificationType _mapAlertTypeToNotificationType(
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

    final mostRecent = _historicalData.first;

    final elapsed = data.timestamp.difference(mostRecent.timestamp);

    return elapsed >= historySampleInterval;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _sensorSubscription?.cancel();

    _pumpSubscription?.cancel();

    _settingsSubscription?.cancel();

    _offlineCheckTimer?.cancel();

    super.dispose();
  }
}