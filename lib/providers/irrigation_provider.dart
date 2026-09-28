import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

enum IrrigationMode { auto, manual }

class IrrigationProvider extends ChangeNotifier {
  final DatabaseReference _pumpRef =
      FirebaseDatabase.instance.ref("smartdrip/pump");

  final DatabaseReference _activityLogsRef =
      FirebaseDatabase.instance.ref("smartdrip/activity_logs");

  bool _isPumpOn = false;
  IrrigationMode _mode = IrrigationMode.auto;

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _pumpStartTime;

  StreamSubscription<DatabaseEvent>? _subscription;

  // =========================
  // HISTORY
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

  String get modeLabel =>
      _mode == IrrigationMode.auto ? "Auto" : "Manual";

  // =========================
  // CONSTRUCTOR
  // =========================

  IrrigationProvider() {
    _listenToFirebase();
  }

  // =========================
  // FIREBASE LISTENER
  // =========================

  void _listenToFirebase() {
    _subscription = _pumpRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data == null || data is! Map) {
          return;
        }

        final pump =
            (data['state'] ?? "OFF")
                .toString()
                .toUpperCase();

        final mode =
            (data['mode'] ?? "auto")
                .toString()
                .toLowerCase();

        final updatedPump = pump == "ON";

        final updatedMode =
            mode == "auto"
                ? IrrigationMode.auto
                : IrrigationMode.manual;

        if (_isPumpOn != updatedPump ||
            _mode != updatedMode) {
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

  // =========================
  // SET PUMP STATE
  // =========================

  Future<bool> setPumpState(bool isOn) async {
    _setLoading(true);

    try {
      await _pumpRef.update({
        "state": isOn ? "ON" : "OFF",
      });

      _isPumpOn = isOn;

      _pumpStartTime =
          isOn ? DateTime.now() : null;

      final action =
          isOn ? "PUMP_ON" : "PUMP_OFF";

      _logEvent(
        action,
        null,
      );

      await _logActivity(action);

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // MODE CHANGE
  // =========================

  Future<bool> setIrrigationMode(
    IrrigationMode mode,
  ) async {
    _setLoading(true);

    try {
      await _pumpRef.update({
        "mode": mode.name,
      });

      _mode = mode;

      // When switching to AUTO,
      // let the ESP32 control the pump.
      if (mode == IrrigationMode.auto) {
        await _pumpRef.update({
          "state": "OFF",
        });

        _isPumpOn = false;

        _pumpStartTime = null;
      }

      final action =
          "MODE_${mode.name.toUpperCase()}";

      _logEvent(
        action,
        null,
      );

      await _logActivity(action);

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      notifyListeners();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // AUTO IRRIGATION
  // =========================
  //
  // Automatic irrigation is handled
  // entirely by the ESP32.
  //
  // The app does NOT make its own
  // automatic irrigation decision.
  //

  void triggerAutoIrrigation(
    double soilPercent,
  ) {
    return;
  }

  // =========================
  // HISTORY LOGGER
  // =========================

  void _logEvent(
    String action,
    double? soil,
  ) {
    _irrigationHistory.insert(
      0,
      {
        "action": action,
        "soil": soil,
        "timestamp":
            DateTime.now().toIso8601String(),
      },
    );

    notifyListeners();
  }

  // =========================
  // ADMIN ACTIVITY LOGGER
  // =========================

  Future<void> _logActivity(String action) async {
    try {
      final firebaseUser =
          FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        return;
      }

      await _activityLogsRef.push().set({
        "uid": firebaseUser.uid,
        "name":
            firebaseUser.displayName ??
            "SmartDrip User",
        "email":
            firebaseUser.email ?? "",
        "action": action,
        "timestamp":
            DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint(
        "Failed to save irrigation activity log: $e",
      );
    }
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