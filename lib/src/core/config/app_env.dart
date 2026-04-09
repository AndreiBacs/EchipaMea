import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static const _stitchApiKeyField = 'STITCH_API_KEY';
  static const _stitchMcpUrlField = 'STITCH_MCP_URL';

  static late final String stitchApiKey;
  static late final String stitchMcpUrl;

  static void initialize() {
    stitchApiKey = dotenv.env[_stitchApiKeyField] ?? '';
    stitchMcpUrl =
        dotenv.env[_stitchMcpUrlField] ?? 'https://stitch.googleapis.com/mcp';
  }
}
