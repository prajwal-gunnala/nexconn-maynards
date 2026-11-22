/// Build-time configuration, passed with `--dart-define`.
///
/// ```
/// flutter run \
///   --dart-define=API_BASE=http://localhost:8787 \
///   --dart-define=DEV_NEXCONN_TOKEN=<token from scripts/nexconn-dev.mjs>
/// ```
class AppConfig {
  const AppConfig._();

  /// Public Nexconn App Key (safe to ship; the App Secret never is).
  static const nexconnAppKey = String.fromEnvironment(
    'NEXCONN_APP_KEY',
    defaultValue: 'tdrvipkstz0f5',
  );

  /// Local API. Reach it from the emulator with `adb reverse tcp:8787 tcp:8787`.
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8787',
  );

  /// Where release builds look up the demo API address (GitHub Pages). Empty disables the lookup.
  static const remoteConfigUrl = String.fromEnvironment(
    'REMOTE_CONFIG',
    defaultValue: 'https://prajwal-gunnala.github.io/nexconn-maynards/config.json',
  );

  /// Dev only: a Nexconn user token. When set and nobody is logged in, the app
  /// skips login, connects with this token and opens [devChannelId].
  static const devNexconnToken = String.fromEnvironment('DEV_NEXCONN_TOKEN');

  /// Dev only: the group channel the spike opens.
  static const devChannelId = String.fromEnvironment(
    'DEV_CHANNEL',
    defaultValue: 'test_street_1',
  );

  /// Dev only: first route, e.g. `/chat/group/test_street_1`.
  static const startRoute = String.fromEnvironment('DEV_START', defaultValue: '/street');

  static bool get hasDevToken => devNexconnToken.isNotEmpty;
}
