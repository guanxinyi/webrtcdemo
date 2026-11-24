/// Compile-time configuration.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
class AppConfig {
  const AppConfig._();

  /// Base URL of the token API (see `server/`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Pre-filled room name on the join screen.
  static const defaultRoom = String.fromEnvironment(
    'DEFAULT_ROOM',
    defaultValue: 'demo-room',
  );
}
