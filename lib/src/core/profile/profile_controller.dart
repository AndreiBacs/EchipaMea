import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfileData>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfileData> {
  static const _fullNameKey = 'profile_full_name';
  static const _phoneKey = 'profile_phone';
  static const _jobTitleKey = 'profile_job_title';
  static const _companyNameKey = 'profile_company_name';
  static const _companyAddressKey = 'profile_company_address';
  static const _companyIbanKey = 'profile_company_iban';
  static const _companyCuiKey = 'profile_company_cui';
  static const _companyVatKey = 'profile_company_vat';
  static const _companyRegComKey = 'profile_company_reg_com';

  @override
  Future<UserProfileData> build() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfileData(
      fullName: prefs.getString(_fullNameKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
      jobTitle: prefs.getString(_jobTitleKey) ?? '',
      companyName: prefs.getString(_companyNameKey) ?? '',
      companyAddress: prefs.getString(_companyAddressKey) ?? '',
      companyIban: prefs.getString(_companyIbanKey) ?? '',
      companyCui: prefs.getString(_companyCuiKey) ?? '',
      companyVat: prefs.getString(_companyVatKey) ?? '',
      companyRegCom: prefs.getString(_companyRegComKey) ?? '',
    );
  }

  Future<void> save({
    required String fullName,
    required String phone,
    required String jobTitle,
    required String companyName,
    required String companyAddress,
    required String companyIban,
    required String companyCui,
    required String companyVat,
    required String companyRegCom,
  }) async {
    final normalized = UserProfileData(
      fullName: fullName.trim(),
      phone: phone.trim(),
      jobTitle: jobTitle.trim(),
      companyName: companyName.trim(),
      companyAddress: companyAddress.trim(),
      companyIban: companyIban.trim(),
      companyCui: companyCui.trim(),
      companyVat: companyVat.trim(),
      companyRegCom: companyRegCom.trim(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fullNameKey, normalized.fullName);
    await prefs.setString(_phoneKey, normalized.phone);
    await prefs.setString(_jobTitleKey, normalized.jobTitle);
    await prefs.setString(_companyNameKey, normalized.companyName);
    await prefs.setString(_companyAddressKey, normalized.companyAddress);
    await prefs.setString(_companyIbanKey, normalized.companyIban);
    await prefs.setString(_companyCuiKey, normalized.companyCui);
    await prefs.setString(_companyVatKey, normalized.companyVat);
    await prefs.setString(_companyRegComKey, normalized.companyRegCom);
    state = AsyncData(normalized);
  }
}

class UserProfileData {
  const UserProfileData({
    required this.fullName,
    required this.phone,
    required this.jobTitle,
    required this.companyName,
    required this.companyAddress,
    required this.companyIban,
    required this.companyCui,
    required this.companyVat,
    required this.companyRegCom,
  });

  final String fullName;
  final String phone;
  final String jobTitle;
  final String companyName;
  final String companyAddress;
  final String companyIban;
  final String companyCui;
  final String companyVat;
  final String companyRegCom;
}
