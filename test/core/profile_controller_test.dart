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
    });

    test('returns stored profile data from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'John Doe',
        'profile_phone': '+40 700 000 000',
        'profile_job_title': 'Engineer',
      });
      final container = makeContainer();
      final profile = await container.read(profileProvider.future);
      expect(profile.fullName, 'John Doe');
      expect(profile.phone, '+40 700 000 000');
      expect(profile.jobTitle, 'Engineer');
    });

    test('returns partial profile when some fields are missing', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Jane',
      });
      final container = makeContainer();
      final profile = await container.read(profileProvider.future);
      expect(profile.fullName, 'Jane');
      expect(profile.phone, '');
      expect(profile.jobTitle, '');
    });
  });

  group('ProfileNotifier.save', () {
    test('updates state with new profile data', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).save(
            fullName: 'Alice Smith',
            phone: '+40 711 222 333',
            jobTitle: 'Manager',
          );

      final profile = container.read(profileProvider).value;
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Alice Smith');
      expect(profile.phone, '+40 711 222 333');
      expect(profile.jobTitle, 'Manager');
    });

    test('trims whitespace from all fields', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).save(
            fullName: '  Bob  ',
            phone: '  +40 700  ',
            jobTitle: '  Dev  ',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, 'Bob');
      expect(profile.phone, '+40 700');
      expect(profile.jobTitle, 'Dev');
    });

    test('persists data to SharedPreferences', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).save(
            fullName: 'Carol',
            phone: '0700',
            jobTitle: 'QA',
          );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_full_name'), 'Carol');
      expect(prefs.getString('profile_phone'), '0700');
      expect(prefs.getString('profile_job_title'), 'QA');
    });

    test('can save empty strings', () async {
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).save(
            fullName: '',
            phone: '',
            jobTitle: '',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, '');
      expect(profile.phone, '');
      expect(profile.jobTitle, '');
    });

    test('overwrites previously saved data', () async {
      SharedPreferences.setMockInitialValues({
        'profile_full_name': 'Old Name',
        'profile_phone': '000',
        'profile_job_title': 'Old Job',
      });
      final container = makeContainer();
      await container.read(profileProvider.future);

      await container.read(profileProvider.notifier).save(
            fullName: 'New Name',
            phone: '111',
            jobTitle: 'New Job',
          );

      final profile = container.read(profileProvider).value;
      expect(profile!.fullName, 'New Name');
      expect(profile.phone, '111');
      expect(profile.jobTitle, 'New Job');
    });
  });

  group('UserProfileData model', () {
    test('stores fullName, phone, and jobTitle', () {
      const data = UserProfileData(
        fullName: 'Dan',
        phone: '0700',
        jobTitle: 'Dev',
      );
      expect(data.fullName, 'Dan');
      expect(data.phone, '0700');
      expect(data.jobTitle, 'Dev');
    });
  });
}
