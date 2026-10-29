import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_controller.dart';
import 'profile_data.dart';
import 'profile_repository.dart';
export 'profile_data.dart';

final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, MyProfile>(
  MyProfileNotifier.new,
);

final companyProvider = AsyncNotifierProvider<CompanyNotifier, CompanyDetails>(
  CompanyNotifier.new,
);

class MyProfileNotifier extends AsyncNotifier<MyProfile> {
  @override
  Future<MyProfile> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    if (!await watchForemanScope(ref)) return const MyProfile();
    return repository.loadProfile();
  }

  /// Saves [profile] with each field trimmed. Throws if the server refuses it,
  /// leaving the state as it was.
  Future<void> save(MyProfile profile) async {
    final saved = await ref
        .read(profileRepositoryProvider)
        .saveProfile(profile.trimmed());
    state = AsyncData(saved);
  }
}

class CompanyNotifier extends AsyncNotifier<CompanyDetails> {
  @override
  Future<CompanyDetails> build() async {
    final repository = ref.watch(profileRepositoryProvider);
    if (!await watchForemanScope(ref)) return const CompanyDetails();
    return repository.loadCompany();
  }

  /// Saves [company] with each field trimmed. Throws if the server refuses it,
  /// leaving the state as it was.
  Future<void> save(CompanyDetails company) async {
    final saved = await ref
        .read(profileRepositoryProvider)
        .saveCompany(company.trimmed());
    state = AsyncData(saved);
  }
}
