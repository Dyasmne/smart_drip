import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the irrigation threshold settings (lower/upper soil moisture %)
/// stored at `smartdrip/settings`, and the automatic-irrigation on/off
/// state stored at `smartdrip/mode`.
///
/// Settings changes are also recorded in:
/// `smartdrip/activity_logs`
class SettingsProvider extends ChangeNotifier {
  final DatabaseReference _settingsRef =
      FirebaseDatabase.instance.ref('smartdrip/settings');

  final DatabaseReference _modeRef =
      FirebaseDatabase.instance.ref('smartdrip/mode');

  final DatabaseReference _pumpRef =
      FirebaseDatabase.instance.ref('smartdrip/pump');

  final DatabaseReference _activityLogsRef =
      FirebaseDatabase.instance.ref('smartdrip/activity_logs');

  // ---- Defaults ----
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
        final mode =
            (event.snapshot.value ?? "auto").toString().toLowerCase();

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

  /// Validates and writes the thresholds to `smartdrip/settings`
  /// and the auto/manual mode to `smartdrip/mode`.
  ///
  /// Also creates an activity log under:
  /// `smartdrip/activity_logs`
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

      // Save soil moisture thresholds.
      await _settingsRef.set({
        'lowerThreshold': lowerThreshold,
        'upperThreshold': upperThreshold,
      });

      // Save irrigation mode.
      await _modeRef.set(
        autoMode ? "auto" : "manual",
      );

      // If automatic irrigation is enabled,
      // make sure the pump starts OFF.
      if (autoMode) {
        await _pumpRef.set("OFF");
      }

      // Update local values.
      _lowerThreshold = lowerThreshold;
      _upperThreshold = upperThreshold;
      _autoMode = autoMode;
      _errorMessage = null;

      // Record the settings change in Firebase.
      await _logSettingsChange(
        lowerThreshold: lowerThreshold,
        upperThreshold: upperThreshold,
        autoMode: autoMode,
      );

      return null;
    } catch (e) {
      debugPrint("SETTINGS SAVE ERROR: $e");

      return "Failed to save settings: $e";
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ================= ACTIVITY LOG =================

  Future<void> _logSettingsChange({
    required double lowerThreshold,
    required double upperThreshold,
    required bool autoMode,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // If nobody is logged in, don't create a user activity log.
      if (user == null) {
        return;
      }

      final userSnapshot =
          await FirebaseDatabase.instance
              .ref('users/${user.uid}')
              .get();

      String name = user.displayName ?? 'Unknown User';
      String role = 'user';

      if (userSnapshot.exists && userSnapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(
          userSnapshot.value as Map,
        );

        name = data['name']?.toString() ?? name;
        role = data['role']?.toString() ?? 'user';
      }

      await _activityLogsRef.push().set({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
        'role': role,
        'action': 'SETTINGS_CHANGED',
        'lowerThreshold': lowerThreshold,
        'upperThreshold': upperThreshold,
        'autoMode': autoMode,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Activity logging should not prevent settings from being saved.
      debugPrint("SETTINGS ACTIVITY LOG ERROR: $e");
    }
  }

  // ================= HELPERS =================

  double? _safeDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _modeSubscription?.cancel();

    super.dispose();
  }
}