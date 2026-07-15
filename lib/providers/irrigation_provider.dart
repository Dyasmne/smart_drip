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
  DateTime? _lastAutoTrigger;

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
  void triggerAutoIrrigation(double soilPercent) {
    if (_mode != IrrigationMode.auto) return;

    final now = DateTime.now();

    if (_lastAutoTrigger != null &&
        now.difference(_lastAutoTrigger!).inSeconds < 30) {
      return;
    }

    if (soilPercent <= 25 && !_isPumpOn) {
      _ref.update({"pump": "ON"});
      _isPumpOn = true;
      _pumpStartTime = now;
      _lastAutoTrigger = now;

      _logEvent("AUTO_PUMP_ON", soilPercent);
      notifyListeners();
    } else if (soilPercent >= 40 && _isPumpOn) {
      _ref.update({"pump": "OFF"});
      _isPumpOn = false;
      _pumpStartTime = null;
      _lastAutoTrigger = now;

      _logEvent("AUTO_PUMP_OFF", soilPercent);
      notifyListeners();
    }
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