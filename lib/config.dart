class ApiConfig {
  /// Адрес backend-сервера. Можно переопределить при сборке:
  /// flutter run --dart-define=API_URL=http://192.168.0.10:8010
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8010',
  );

  static const String appName = 'Рапортичка';
}