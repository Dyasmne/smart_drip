import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';

/// Manages global app settings (theme, preferences)
class AppProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isInitialized = false;
  bool _isLoading = false;

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  AppProvider() {
    _init();
  }

  /// Initialize preferences safely
  Future<void> _init() async {
    await _loadPreferences();
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(AppConfig.keyDarkMode) ?? false;
    } catch (e) {
      debugPrint('AppProvider: Failed to load preferences: $e');
      _isDarkMode = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Toggle theme mode
  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  /// Set theme mode
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    notifyListeners();

    await _savePreferences();
  }

  /// Save preferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.keyDarkMode, _isDarkMode);
    } catch (e) {
      debugPrint('AppProvider: Failed to save preferences: $e');
    }
  }

  /// Reset preferences
  Future<void> resetPreferences() async {
    _isDarkMode = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.keyDarkMode);
    } catch (e) {
      debugPrint('AppProvider: Failed to reset preferences: $e');
    }
  }
}