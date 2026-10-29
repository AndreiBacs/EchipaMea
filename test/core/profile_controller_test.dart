import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/network/api_exception.dart';
import 'package:echipa_mea/src/core/profile/profile_controller.dart';

import '../support/fake_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('mock mode (SharedPreferences)', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('both records are empty when nothing is stored', () async {
      final container = makeContainer();
      expect(await container.read(myProfileProvider.future), const MyProfile());
      expect(
        await container.read(companyProvider.future),
        const CompanyDetails(),
      );
    });

    test(
      'reads stored values; the old free-text address is the street',
      () async {
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

        expect(
          await container.read(myProfileProvider.future),
          const MyProfile(
            fullName: 'John Doe',
            phone: '+40 700 000 000',
            jobTitle: 'Engineer',
          ),
        );
        expect(
          await container.read(companyProvider.future),
          const CompanyDetails(
            name: 'Build SRL',
            addressLine1: 'Str. Exemplu 12',
            iban: 'RO49AAAA1B31007593840000',
            cui: 'RO12345678',
            vatNumber: 'RO12345678',
            regCom: 'J40/1234/2020',
          ),
        );
      },
    );

    test('saving trims every field and persists it', () async {
      final container = makeContainer();
      await container.read(myProfileProvider.future);
      await container.read(companyProvider.future);

      await container
          .read(myProfileProvider.notifier)
          .save(
            const MyProfile(
              fullName: '  Carol ',
              phone: ' 0700 ',
              jobTitle: ' QA ',
            ),
          );
      await container
          .read(companyProvider.notifier)
          .save(
            const CompanyDetails(
              name: ' Carol Works ',
              addressLine1: ' Str. Lunga 1 ',
              city: ' Cluj-Napoca ',
              state: ' Cluj ',
              zipCode: ' 400001 ',
              iban: ' RO99AAAA ',
              cui: ' RO777 ',
              vatNumber: ' RO777 ',
              regCom: ' J12/77/2021 ',
            ),
          );

      expect(
        container.read(myProfileProvider).value,
        const MyProfile(fullName: 'Carol', phone: '0700', jobTitle: 'QA'),
      );
      expect(container.read(companyProvider).value!.city, 'Cluj-Napoca');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('profile_full_name'), 'Carol');
      expect(prefs.getString('profile_job_title'), 'QA');
      expect(prefs.getString('profile_company_name'), 'Carol Works');
      expect(prefs.getString('profile_company_address'), 'Str. Lunga 1');
      expect(prefs.getString('profile_company_city'), 'Cluj-Napoca');
      expect(prefs.getString('profile_company_state'), 'Cluj');
      expect(prefs.getString('profile_company_zip_code'), '400001');
      expect(prefs.getString('profile_company_iban'), 'RO99AAAA');
      expect(prefs.getString('profile_company_cui'), 'RO777');
      expect(prefs.getString('profile_company_vat'), 'RO777');
      expect(prefs.getString('profile_company_reg_com'), 'J12/77/2021');
    });

    test('a fresh container reads back what was saved', () async {
      final first = makeContainer();
      await first.read(companyProvider.future);
      await first
          .read(companyProvider.notifier)
          .save(const CompanyDetails(name: 'Kept SRL', city: 'Iasi'));

      final second = makeContainer();
      final company = await second.read(companyProvider.future);
      expect(company.name, 'Kept SRL');
      expect(company.city, 'Iasi');
    });
  });

  group('with a backend', () {
    late FakeServer server;

    setUp(() {
      useFakeBackend();
      server = FakeServer()
        ..on(
          'GET',
          '/me/profile',
          (_) => jsonResponse(_profileJson(fullName: 'Sef de echipa')),
        )
        ..on('GET', '/company', (_) => jsonResponse(_companyJson()));
    });

    test('loads the profile and the company with the foreman token', () async {
      final container = makeApiContainer(server: server, store: foremanStore());

      final profile = await container.read(myProfileProvider.future);
      final company = await container.read(companyProvider.future);

      expect(profile.fullName, 'Sef de echipa');
      expect(company.name, 'Demo Construct SRL');
      expect(company.city, 'Cluj-Napoca');
      expect(server.requests.map(bearerOf), everyElement('access-1'));
    });

    test(
      'saving the profile PATCHes /me/profile and keeps the reply',
      () async {
        server.on('PATCH', '/me/profile', (request) {
          final body = jsonBodyOf(request);
          return jsonResponse(_profileJson(fullName: '${body['fullName']}!'));
        });
        final container = makeApiContainer(
          server: server,
          store: foremanStore(),
        );
        await container.read(myProfileProvider.future);

        await container
            .read(myProfileProvider.notifier)
            .save(
              const MyProfile(fullName: ' Ana ', phone: '07', jobTitle: 'X'),
            );

        final patch = server.requests.last;
        expect(jsonBodyOf(patch), {
          'fullName': 'Ana',
          'phone': '07',
          'jobTitle': 'X',
        });
        expect(container.read(myProfileProvider).value!.fullName, 'Ana!');
      },
    );

    test('saving the company leaves out an empty name', () async {
      server.on('PATCH', '/company', (_) => jsonResponse(_companyJson()));
      final container = makeApiContainer(server: server, store: foremanStore());
      await container.read(companyProvider.future);

      await container
          .read(companyProvider.notifier)
          .save(const CompanyDetails(city: 'Iasi'));

      final body = jsonBodyOf(server.requests.last);
      expect(body.containsKey('name'), isFalse);
      expect(body['city'], 'Iasi');
    });

    test('a refused save throws and leaves the state alone', () async {
      server.on(
        'PATCH',
        '/company',
        (_) => errorResponse(400, 'VALIDATION_FAILED', field: 'iban'),
      );
      final container = makeApiContainer(server: server, store: foremanStore());
      final before = await container.read(companyProvider.future);

      await expectLater(
        container
            .read(companyProvider.notifier)
            .save(const CompanyDetails(name: 'X', iban: 'nope')),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'iban')),
      );
      expect(container.read(companyProvider).value, before);
    });

    test('nothing is fetched while no foreman is signed in', () async {
      final container = makeApiContainer(server: server);

      expect(await container.read(myProfileProvider.future), const MyProfile());
      expect(
        await container.read(companyProvider.future),
        const CompanyDetails(),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('value equality', () {
    test('trimmed copies of equal records are equal', () {
      expect(
        const MyProfile(fullName: ' A ').trimmed(),
        const MyProfile(fullName: 'A'),
      );
      expect(
        const CompanyDetails(name: 'A ', regCom: ' J1').trimmed(),
        const CompanyDetails(name: 'A', regCom: 'J1'),
      );
      expect(
        const CompanyDetails(name: 'A'),
        isNot(const CompanyDetails(name: 'A', city: 'B')),
      );
    });
  });
}

Map<String, dynamic> _profileJson({required String fullName}) => {
  'userId': 'foreman_local',
  'email': 'foreman@echipamea.local',
  'role': 'foreman',
  'fullName': fullName,
  'phone': '+40 700 000 000',
  'jobTitle': 'Sef de echipa',
  'companyId': 'demo-company',
  'companyName': 'Demo Construct SRL',
};

Map<String, dynamic> _companyJson() => {
  'id': 'demo-company',
  'name': 'Demo Construct SRL',
  'addressLine1': 'Str. Fabricii 5',
  'city': 'Cluj-Napoca',
  'state': 'Cluj',
  'zipCode': '400001',
  'addressLine': 'Str. Fabricii 5, Cluj-Napoca, Cluj, 400001',
  'iban': 'RO49AAAA1B31007593840000',
  'cui': 'RO12345678',
  'vatNumber': 'RO12345678',
  'regCom': 'J12/1234/2020',
};
