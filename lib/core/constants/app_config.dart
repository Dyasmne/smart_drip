/// Application configuration constants
class AppConfig {
  AppConfig._();

  // App info
  static const String appName = 'SmartDrip';
  static const String appSubtitle = 'Smart Irrigation Monitoring System';
  static const String appVersion = '1.0.0';

  // Splash screen duration (seconds)
  static const int splashDuration = 3;

  // Sensor refresh interval (seconds)
  static const int sensorRefreshInterval = 30;

  // Moisture thresholds (percentage)
  static const double moistureLowThreshold = 30.0;
  static const double moistureOptimalMin = 40.0;
  static const double moistureOptimalMax = 70.0;
  static const double moistureHighThreshold = 80.0;

  // Mock data config
  static const bool useMockData = true;

  // Firebase config keys (placeholder)
  static const String firebaseProjectId = 'smartdrip-iot';

  // ESP32 config (placeholder)
  static const String esp32DefaultIP = '192.168.1.100';
  static const int esp32Port = 80;

  // Notification channel
  static const String notificationChannelId = 'smartdrip_channel';
  static const String notificationChannelName = 'SmartDrip Alerts';

  // SharedPreferences keys
  static const String keyDarkMode = 'dark_mode';
  static const String keyUserEmail = 'user_email';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyIrrigationMode = 'irrigation_mode';
}