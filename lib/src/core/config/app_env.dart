import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment-derived configuration.
///
/// The fields default to "unset" rather than being `late final`. Reading config
/// before [initialize] used to throw a `LateInitializationError`, which meant a
/// widget test that happened to touch a code path reading `AUTH_API_BASE_URL`
/// crashed on the config lookup instead of taking the mock-mode branch. Empty is
/// the honest answer for "no backend configured", and it is also what CI sets.
class AppEnv {
  static const _stitchApiKeyField = 'STITCH_API_KEY';
  static const _stitchMcpUrlField = 'STITCH_MCP_URL';
  static const _authApiBaseUrlField = 'AUTH_API_BASE_URL';
  static const _appDownloadUrlField = 'APP_DOWNLOAD_URL';
  static const _appLandingUrlField = 'APP_LANDING_URL';
  static const _appIosTestflightUrlField = 'APP_IOS_TESTFLIGHT_URL';
  static const _workerTelemetryWsUrlField = 'WORKER_TELEMETRY_WS_URL';
  static const _workerReportsApiUrlField = 'WORKER_REPORTS_API_URL';
  static const _foremanNotificationsWsUrlField = 'FOREMAN_NOTIFICATIONS_WS_URL';

  static String stitchApiKey = '';
  static String stitchMcpUrl = 'https://stitch.googleapis.com/mcp';

  /// Root of the API. Empty means mock mode: no network, seeded demo data.
  static String authApiBaseUrl = '';
  static String appDownloadUrl = '';
  static String appLandingUrl = '';
  static String appIosTestflightUrl = '';
  static String workerTelemetryWsUrl = '';
  static String workerReportsApiUrl = '';
  static String foremanNotificationsWsUrl = '';

  /// True when a backend is configured and the app should talk to it. This is
  /// the one mock-mode switch; nothing else should test the URL itself.
  static bool get hasBackend => apiBaseUrl.isNotEmpty;

  /// [authApiBaseUrl] trimmed, without trailing slashes, ready for `'$base/x'`.
  static String get apiBaseUrl =>
      authApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static void initialize() {
    stitchApiKey = dotenv.env[_stitchApiKeyField] ?? '';
    stitchMcpUrl =
        dotenv.env[_stitchMcpUrlField] ?? 'https://stitch.googleapis.com/mcp';
    authApiBaseUrl = dotenv.env[_authApiBaseUrlField] ?? '';
    appDownloadUrl = dotenv.env[_appDownloadUrlField] ?? '';
    appLandingUrl = dotenv.env[_appLandingUrlField] ?? '';
    appIosTestflightUrl = dotenv.env[_appIosTestflightUrlField] ?? '';
    workerTelemetryWsUrl = dotenv.env[_workerTelemetryWsUrlField] ?? '';
    workerReportsApiUrl = dotenv.env[_workerReportsApiUrlField] ?? '';
    foremanNotificationsWsUrl =
        dotenv.env[_foremanNotificationsWsUrlField] ?? '';
  }
}
