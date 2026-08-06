class ApiConstants {
  ApiConstants._();

  /// Overridden at build time via --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'accessToken';
  static const String refreshToken = 'refreshToken';
  static const String cachedUser = 'cachedUser';
  static const String themeMode = 'themeMode';
  static const String languageCode = 'languageCode';
}

class HiveBoxes {
  HiveBoxes._();

  static const String offlineQueue = 'offline_queue';
  static const String tripsCache = 'trips_cache';
}
