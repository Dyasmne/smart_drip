import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Manages the irrigation threshold settings (lower/upper soil moisture %)
/// stored at `smartdrip/settings`, and the automatic-irrigation on/off
/// state, which is stored at `smartdrip/mode` ("auto" | "manual").
///
/// IMPORTANT: `smartdrip/mode` is shared with ControlScreen/IrrigationProvider
/// — it's the single, app-wide source of truth for auto vs. manual, so both
/// screens read and write the exact same field instead of each keeping its
/// own separate "is auto irrigation on" flag. The ESP32 firmware only ever
/// *reads* this field; it never writes it back, so a change made here always
/// wins without being raced/overwritten by the device.
class SettingsProvider extends ChangeNotifier {
  final DatabaseReference _settingsRef =
      FirebaseDatabase.instance.ref('smartdrip/settings');
  final DatabaseReference _modeRef =
      FirebaseDatabase.instance.ref('smartdrip/mode');
  final DatabaseReference _pumpRef =
      FirebaseDatabase.instance.ref('smartdrip/pump');

  // ---- Defaults (mirror the ESP32 firmware's fallback values) ----
  double _lowerThreshold = 30;
  double _upperThreshold = 45;
  bool _autoMode = true;

  bool _isLoadingSettings = true;
  bool _isLoadingMode = true;
  bool _isSaving = false;
  String? _errorMessage;

  StreamSubscription<DatabaseEvent>? _settingsSubscription;
  StreamSubscription<DatabaseEvent>? _modeSubscription;

  // ================= GETTERS =================

  double get lowerThreshold => _lowerThreshold;
  double get upperThreshold => _upperThreshold;
  bool get autoMode => _autoMode;

  bool get isLoading => _isLoadingSettings || _isLoadingMode;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // ================= CONSTRUCTOR =================

  SettingsProvider() {
    _startListeners();
  }

  void _startListeners() {
    _settingsSubscription?.cancel();
    _modeSubscription?.cancel();

    _settingsSubscription = _settingsRef.onValue.listen(
      (event) {
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          final map = Map<dynamic, dynamic>.from(data);
          _lowerThreshold =
              _safeDouble(map['lowerThreshold']) ?? _lowerThreshold;
          _upperThreshold =
              _safeDouble(map['upperThreshold']) ?? _upperThreshold;
        }

        _isLoadingSettings = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("SETTINGS FIREBASE ERROR: $error");
        _errorMessage = error.toString();
        _isLoadingSettings = false;
        notifyListeners();
      },
    );

    _modeSubscription = _modeRef.onValue.listen(
      (event) {
        final mode = (event.snapshot.value ?? "auto").toString().toLowerCase();
        _autoMode = mode == "auto";

        _isLoadingMode = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("MODE FIREBASE ERROR: $error");
        _errorMessage = error.toString();
        _isLoadingMode = false;
        notifyListeners();
      },
    );
  }

  // ================= SAVE =================

  /// Validates and writes the thresholds to `smartdrip/settings`, and the
  /// auto/manual toggle to the shared `smartdrip/mode` field.
  /// Returns null on success, or an error message to show the user.
  Future<String?> saveSettings({
    required double lowerThreshold,
    required double upperThreshold,
    required bool autoMode,
  }) async {
    if (lowerThreshold < 0 || upperThreshold > 100) {
      return "Thresholds must be between 0% and 100%.";
    }
    if (lowerThreshold >= upperThreshold) {
      return "Lower threshold must be less than upper threshold.";
    }

    try {
      _isSaving = true;
      notifyListeners();

      await _settingsRef.set({
        'lowerThreshold': lowerThreshold,
        'upperThreshold': upperThreshold,
      });

      await _modeRef.set(autoMode ? "auto" : "manual");

      // Match ControlScreen/IrrigationProvider's existing behavior: turning
      // automatic irrigation ON forces the pump off immediately, since the
      // ESP32's auto logic (not a stale manual "ON") should decide from here.
      if (autoMode) {
        await _pumpRef.set("OFF");
      }

      _lowerThreshold = lowerThreshold;
      _upperThreshold = upperThreshold;
      _autoMode = autoMode;
      _errorMessage = null;

      return null;
    } catch (e) {
      debugPrint("SETTINGS SAVE ERROR: $e");
      return "Failed to save settings: $e";
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _modeSubscription?.cancel();
    super.dispose();
  }
}