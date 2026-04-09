import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  static late final String stitchApiKey;
  static late final String stitchMcpUrl;
  static late final String authApiBaseUrl;
  static late final String appDownloadUrl;
  static late final String appLandingUrl;
  static late final String appIosTestflightUrl;
  static late final String workerTelemetryWsUrl;
  static late final String workerReportsApiUrl;
  static late final String foremanNotificationsWsUrl;

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
