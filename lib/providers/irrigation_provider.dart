import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

enum IrrigationMode { auto, manual }

class IrrigationProvider extends ChangeNotifier {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref("smartdrip");

  bool _isPumpOn = false;
  IrrigationMode _mode = IrrigationMode.auto;

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _pumpStartTime;

  StreamSubscription<DatabaseEvent>? _subscription;


  // =========================
  // HISTORY (ADDED FIX)
  // =========================
  final List<Map<String, dynamic>> _irrigationHistory = [];

  List<Map<String, dynamic>> get irrigationHistory =>
      List.unmodifiable(_irrigationHistory);

  // =========================
  // GETTERS
  // =========================
  bool get isPumpOn => _isPumpOn;
  IrrigationMode get irrigationMode => _mode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get pumpStartTime => _pumpStartTime;

  String get modeLabel => _mode == IrrigationMode.auto ? "Auto" : "Manual";

  IrrigationProvider() {
    _listenToFirebase();
  }

  // =========================
  // FIREBASE LISTENER
  // =========================
  void _listenToFirebase() {
    _subscription = _ref.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data == null || data is! Map) return;

        final pump = (data['pump'] ?? "OFF").toString().toUpperCase();
        final mode = (data['mode'] ?? "auto").toString().toLowerCase();

        final updatedPump = pump == "ON";
        final updatedMode =
            mode == "auto" ? IrrigationMode.auto : IrrigationMode.manual;

        if (_isPumpOn != updatedPump || _mode != updatedMode) {
          _isPumpOn = updatedPump;
          _mode = updatedMode;
          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // =========================
  // PUMP TOGGLE
  // =========================
  Future<bool> togglePump() async {
    return setPumpState(!_isPumpOn);
  }

  Future<bool> setPumpState(bool isOn) async {
    _setLoading(true);

    try {
      await _ref.update({
        "pump": isOn ? "ON" : "OFF",
      });

      _isPumpOn = isOn;
      _pumpStartTime = isOn ? DateTime.now() : null;

      _logEvent(isOn ? "PUMP_ON" : "PUMP_OFF", null);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // MODE CHANGE
  // =========================
  Future<bool> setIrrigationMode(IrrigationMode mode) async {
    _setLoading(true);

    try {
      await _ref.update({
        "mode": mode.name,
      });

      _mode = mode;

      if (mode == IrrigationMode.auto) {
        await _ref.update({"pump": "OFF"});
        _isPumpOn = false;
        _pumpStartTime = null;
      }

      _logEvent("MODE_${mode.name.toUpperCase()}", null);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // AUTO IRRIGATION
  // =========================
  //
  // DISABLED: the ESP32 firmware is now the single source of truth for
  // automatic irrigation decisions. It reads live soil moisture straight
  // from its own sensor (no network round-trip) and the lower/upper
  // thresholds from `smartdrip/settings`, so it keeps working correctly
  // even if this app is closed or the phone is offline.
  //
  // This method used to *also* toggle `smartdrip/pump` client-side using
  // its own hardcoded thresholds (25% / 40%) whenever new sensor data came
  // in — completely independent from, and inconsistent with, the ESP32's
  // own thresholds. Having two independent auto-deciders writing to the
  // same Firebase field risked conflicting/flapping pump state, so this is
  // now a deliberate no-op. The method is kept (rather than deleted) so any
  // existing call sites (e.g. in SensorProvider) don't break.
  void triggerAutoIrrigation(double soilPercent) {
    // Intentionally does nothing. See comment above.
    return;
  }

  // =========================
  // HISTORY LOGGER
  // =========================
  void _logEvent(String action, double? soil) {
    _irrigationHistory.insert(0, {
      "action": action,
      "soil": soil,
      "timestamp": DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  // =========================
  // LOADING
  // =========================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =========================
  // DISPOSE
  // =========================
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}