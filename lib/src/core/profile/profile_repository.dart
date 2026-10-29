import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_session_controller.dart';
import '../config/app_env.dart';
import '../network/api_client.dart';
import 'profile_data.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiProfileRepository(ref.watch(foremanApiProvider))
      : PrefsProfileRepository(),
);

abstract interface class ProfileRepository {
  Future<MyProfile> loadProfile();
  Future<MyProfile> saveProfile(MyProfile profile);
  Future<CompanyDetails> loadCompany();
  Future<CompanyDetails> saveCompany(CompanyDetails company);
}

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<MyProfile> loadProfile() async =>
      _profileFromJson(await _api.get('/me/profile'));

  @override
  Future<MyProfile> saveProfile(MyProfile profile) async => _profileFromJson(
    await _api.patch(
      '/me/profile',
      body: {
        'fullName': profile.fullName,
        'phone': profile.phone,
        'jobTitle': profile.jobTitle,
      },
    ),
  );

  @override
  Future<CompanyDetails> loadCompany() async =>
      _companyFromJson(await _api.get('/company'));

  @override
  Future<CompanyDetails> saveCompany(CompanyDetails company) async =>
      _companyFromJson(
        await _api.patch(
          '/company',
          body: {
            // The server refuses an empty name; leaving it out keeps the
            // current one.
            if (company.name.isNotEmpty) 'name': company.name,
            'addressLine1': company.addressLine1,
            'city': company.city,
            'state': company.state,
            'zipCode': company.zipCode,
            'iban': company.iban,
            'cui': company.cui,
            'vatNumber': company.vatNumber,
            'regCom': company.regCom,
          },
        ),
      );

  static MyProfile _profileFromJson(Json json) => MyProfile(
    fullName: json['fullName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    jobTitle: json['jobTitle'] as String? ?? '',
  );

  static CompanyDetails _companyFromJson(Json json) => CompanyDetails(
    name: json['name'] as String? ?? '',
    addressLine1: json['addressLine1'] as String? ?? '',
    city: json['city'] as String? ?? '',
    state: json['state'] as String? ?? '',
    zipCode: json['zipCode'] as String? ?? '',
    iban: json['iban'] as String? ?? '',
    cui: json['cui'] as String? ?? '',
    vatNumber: json['vatNumber'] as String? ?? '',
    regCom: json['regCom'] as String? ?? '',
  );
}

/// Mock mode: both records live in SharedPreferences on this device.
class PrefsProfileRepository implements ProfileRepository {
  static const _fullNameKey = 'profile_full_name';
  static const _phoneKey = 'profile_phone';
  static const _jobTitleKey = 'profile_job_title';
  static const _companyNameKey = 'profile_company_name';
  // Held the whole free-text address before the address was split into parts;
  // an old value reads back as the street line.
  static const _companyAddressKey = 'profile_company_address';
  static const _companyCityKey = 'profile_company_city';
  static const _companyStateKey = 'profile_company_state';
  static const _companyZipCodeKey = 'profile_company_zip_code';
  static const _companyIbanKey = 'profile_company_iban';
  static const _companyCuiKey = 'profile_company_cui';
  static const _companyVatKey = 'profile_company_vat';
  static const _companyRegComKey = 'profile_company_reg_com';

  @override
  Future<MyProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return MyProfile(
      fullName: prefs.getString(_fullNameKey) ?? '',
      phone: prefs.getString(_phoneKey) ?? '',
      jobTitle: prefs.getString(_jobTitleKey) ?? '',
    );
  }

  @override
  Future<MyProfile> saveProfile(MyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fullNameKey, profile.fullName);
    await prefs.setString(_phoneKey, profile.phone);
    await prefs.setString(_jobTitleKey, profile.jobTitle);
    return profile;
  }

  @override
  Future<CompanyDetails> loadCompany() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanyDetails(
      name: prefs.getString(_companyNameKey) ?? '',
      addressLine1: prefs.getString(_companyAddressKey) ?? '',
      city: prefs.getString(_companyCityKey) ?? '',
      state: prefs.getString(_companyStateKey) ?? '',
      zipCode: prefs.getString(_companyZipCodeKey) ?? '',
      iban: prefs.getString(_companyIbanKey) ?? '',
      cui: prefs.getString(_companyCuiKey) ?? '',
      vatNumber: prefs.getString(_companyVatKey) ?? '',
      regCom: prefs.getString(_companyRegComKey) ?? '',
    );
  }

  @override
  Future<CompanyDetails> saveCompany(CompanyDetails company) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyNameKey, company.name);
    await prefs.setString(_companyAddressKey, company.addressLine1);
    await prefs.setString(_companyCityKey, company.city);
    await prefs.setString(_companyStateKey, company.state);
    await prefs.setString(_companyZipCodeKey, company.zipCode);
    await prefs.setString(_companyIbanKey, company.iban);
    await prefs.setString(_companyCuiKey, company.cui);
    await prefs.setString(_companyVatKey, company.vatNumber);
    await prefs.setString(_companyRegComKey, company.regCom);
    return company;
  }
}
