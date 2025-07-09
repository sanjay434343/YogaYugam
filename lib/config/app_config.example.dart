
class AppConfig {
  static const String currentVersion = '1.0.0';
  static const bool isDevelopment = bool.fromEnvironment('DEV_MODE', defaultValue: false);
  
  // Add other configuration variables as needed
}