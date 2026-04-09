import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfileData>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfileData> {
  static const _fullNameKey = 'profile_full_name';
  static const _phoneKey = 'profile_phone';
  static const _jobTitleKey = 'profile_job_title';

  @override
  Future<UserProfileData> build() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileData(
      fullName: prefs.getString(_fullNameKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
      jobTitle: prefs.getString(_jobTitleKey) ?? '',
    );
  }

  Future<void> save({
    required String fullName,
    required String phone,
    required String jobTitle,
  }) async {
    final normalized = UserProfileData(
      fullName: fullName.trim(),
      phone: phone.trim(),
      jobTitle: jobTitle.trim(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fullNameKey, normalized.fullName);
    await prefs.setString(_phoneKey, normalized.phone);
    await prefs.setString(_jobTitleKey, normalized.jobTitle);
    state = AsyncData(normalized);
  }
}

class UserProfileData {
  const UserProfileData({
    required this.fullName,
    required this.phone,
    required this.jobTitle,
  });

  final String fullName;
  final String phone;
  final String jobTitle;
}
