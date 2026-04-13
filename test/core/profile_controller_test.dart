import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/profile/profile_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('ProfileNotifier.build', () {
    test('returns empty profile when nothing is stored', () async {
      final container = makeContainer();
      final profile = await container.read(profileProvider.future);
      expect(profile.fullName, '');
      expect(profile.phone, '');
      expect(profile.jobTitle, '');
      expect(profile.companyName, '');
      expect(profile.companyAddress, '');
      expect(profile.companyIban, '');
      expect(profile.companyCui, '');
      expect(profile.companyVat, '');
      expect(profile.companyRegCom, '');
    });

    test('returns stored profile data from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'John Doe',
        'profile_phone': '+40 700 000 000',
        'profile_job_title': 'Engineer',
        'profile_company_name': 'Build SRL',
        'profile_company_address': 'Str. Exemplu 12',
        'profile_company_iban': 'RO49AAAA1B31007593840000',
        'profile_company_cui': 'RO12345678',
        'profile_company_vat': 'RO12345678',
        'profile_company_reg_com': 'J40/1234/2020',
      });
      final container = makeContainer();
      final profile = await container.read(profileProvider.future);
      expect(profile.fullName, 'John Doe');
      expect(profile.phone, '+40 700 000 000');
      expect(profile.jobTitle, 'Engineer');
      expect(profile.companyName, 'Build SRL');
      expect(profile.companyAddress, 'Str. Exemplu 12');
      expect(profile.companyIban, 'RO49AAAA1B31007593840000');
      expect(profile.companyCui, 'RO12345678');
      expect(profile.companyVat, 'RO12345678');
      expect(profile.companyRegCom, 'J40/1234/2020');
    });

    test('returns partial profile when some fields are missing', () async {
      SharedPreferences.setMockInitialValues({'profile_full_name': 'Jane'});
      final container = makeContainer();
      final profile = await container.read(profileProvider.future);
      expect(profile.fullName, 'Jane');
      expect(profile.phone, '');
      expect(profile.jobTitle, '');
      expect(profile.companyName, '');
      expect(profile.companyAddress, '');
      expect(profile.companyIban, '');
      expect(profile.companyCui, '');
      expect(profile.companyVat, '');
      expect(profile.companyRegCom, '');
    });
  });

  group('ProfileNotifier.save', () {
    test('updates state with new profile data', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container
          .read(profileProvider.notifier)
          .save(
            fullName: 'Alice Smith',
            phone: '+40 711 222 333',
            jobTitle: 'Manager',
            companyName: 'Construct Team SRL',
            companyAddress: 'Bucuresti, Str. Constructorilor 10',
            companyIban: 'RO49AAAA1B31007593840000',
            companyCui: 'RO12345678',
            companyVat: 'RO12345678',
            companyRegCom: 'J40/1234/2020',
          );

      final profile = container.read(profileProvider).value;
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Alice Smith');
      expect(profile.phone, '+40 711 222 333');
      expect(profile.jobTitle, 'Manager');
      expect(profile.companyName, 'Construct Team SRL');
      expect(profile.companyAddress, 'Bucuresti, Str. Constructorilor 10');
      expect(profile.companyIban, 'RO49AAAA1B31007593840000');
      expect(profile.companyCui, 'RO12345678');
      expect(profile.companyVat, 'RO12345678');
      expect(profile.companyRegCom, 'J40/1234/2020');
    });

    test('trims whitespace from all fields', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container
          .read(profileProvider.notifier)
          .save(
            fullName: '  Bob  ',
            phone: '  +40 700  ',
            jobTitle: '  Dev  ',
            companyName: '  Bob Construct  ',
            companyAddress: '  Str. Bob 1  ',
            companyIban: '  RO11BANK0000  ',
            companyCui: '  RO999  ',
            companyVat: '  RO999  ',
            companyRegCom: '  J01/99/2024  ',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, 'Bob');
      expect(profile.phone, '+40 700');
      expect(profile.jobTitle, 'Dev');
      expect(profile.companyName, 'Bob Construct');
      expect(profile.companyAddress, 'Str. Bob 1');
      expect(profile.companyIban, 'RO11BANK0000');
      expect(profile.companyCui, 'RO999');
      expect(profile.companyVat, 'RO999');
      expect(profile.companyRegCom, 'J01/99/2024');
    });

    test('persists data to SharedPreferences', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container
          .read(profileProvider.notifier)
          .save(
            fullName: 'Carol',
            phone: '0700',
            jobTitle: 'QA',
            companyName: 'Carol Works',
            companyAddress: 'Cluj',
            companyIban: 'RO99AAAA',
            companyCui: 'RO777',
            companyVat: 'RO777',
            companyRegCom: 'J12/77/2021',
          );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_full_name'), 'Carol');
      expect(prefs.getString('profile_phone'), '0700');
      expect(prefs.getString('profile_job_title'), 'QA');
      expect(prefs.getString('profile_company_name'), 'Carol Works');
      expect(prefs.getString('profile_company_address'), 'Cluj');
      expect(prefs.getString('profile_company_iban'), 'RO99AAAA');
      expect(prefs.getString('profile_company_cui'), 'RO777');
      expect(prefs.getString('profile_company_vat'), 'RO777');
      expect(prefs.getString('profile_company_reg_com'), 'J12/77/2021');
    });

    test('can save empty strings', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container
          .read(profileProvider.notifier)
          .save(
            fullName: '',
            phone: '',
            jobTitle: '',
            companyName: '',
            companyAddress: '',
            companyIban: '',
            companyCui: '',
            companyVat: '',
            companyRegCom: '',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, '');
      expect(profile.phone, '');
      expect(profile.jobTitle, '');
      expect(profile.companyName, '');
      expect(profile.companyAddress, '');
      expect(profile.companyIban, '');
      expect(profile.companyCui, '');
      expect(profile.companyVat, '');
      expect(profile.companyRegCom, '');
    });

    test('overwrites previously saved data', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Old Name',
        'profile_phone': '000',
        'profile_job_title': 'Old Job',
        'profile_company_name': 'Old Company',
        'profile_company_address': 'Old Address',
        'profile_company_iban': 'OLDIBAN',
        'profile_company_cui': 'OLDCUI',
        'profile_company_vat': 'OLDVAT',
        'profile_company_reg_com': 'OLDREG',
      });
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container
          .read(profileProvider.notifier)
          .save(
            fullName: 'New Name',
            phone: '111',
            jobTitle: 'New Job',
            companyName: 'New Company',
            companyAddress: 'New Address',
            companyIban: 'NEWIBAN',
            companyCui: 'NEWCUI',
            companyVat: 'NEWVAT',
            companyRegCom: 'NEWREG',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, 'New Name');
      expect(profile.phone, '111');
      expect(profile.jobTitle, 'New Job');
      expect(profile.companyName, 'New Company');
      expect(profile.companyAddress, 'New Address');
      expect(profile.companyIban, 'NEWIBAN');
      expect(profile.companyCui, 'NEWCUI');
      expect(profile.companyVat, 'NEWVAT');
      expect(profile.companyRegCom, 'NEWREG');
    });
  });

  group('UserProfileData model', () {
    test('stores personal and company fields', () {
      const data = UserProfileData(
        fullName: 'Dan',
        phone: '0700',
        jobTitle: 'Dev',
        companyName: 'Dan Construct',
        companyAddress: 'Oradea',
        companyIban: 'RO00DAN',
        companyCui: 'ROCUI',
        companyVat: 'ROVAT',
        companyRegCom: 'J05/1/2025',
      );
      expect(data.fullName, 'Dan');
      expect(data.phone, '0700');
      expect(data.jobTitle, 'Dev');
      expect(data.companyName, 'Dan Construct');
      expect(data.companyAddress, 'Oradea');
      expect(data.companyIban, 'RO00DAN');
      expect(data.companyCui, 'ROCUI');
      expect(data.companyVat, 'ROVAT');
      expect(data.companyRegCom, 'J05/1/2025');
    });
  });
}
