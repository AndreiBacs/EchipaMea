import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final setupFlowCompletedProvider =
    AsyncNotifierProvider<SetupFlowNotifier, bool>(SetupFlowNotifier.new);

class SetupFlowNotifier extends AsyncNotifier<bool> {
  static const _prefsKey = 'app_initial_setup_completed';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    state = const AsyncData(true);
  }
}
