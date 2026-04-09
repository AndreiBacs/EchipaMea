import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';

final homeControllerProvider = Provider<HomeViewModel>((ref) {
  return HomeViewModel(
    stitchMcpUrl: AppEnv.stitchMcpUrl,
    hasStitchApiKey: AppEnv.stitchApiKey.isNotEmpty,
  );
});

class HomeViewModel {
  HomeViewModel({required this.stitchMcpUrl, required this.hasStitchApiKey});

  final String stitchMcpUrl;
  final bool hasStitchApiKey;
}
