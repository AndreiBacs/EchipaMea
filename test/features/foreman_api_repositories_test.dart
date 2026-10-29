import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/auth/auth_session_controller.dart';
import 'package:echipa_mea/src/core/domain/entities/worker_role.dart';
import 'package:echipa_mea/src/core/network/api_exception.dart';
import 'package:echipa_mea/src/core/ui/async_status_view.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/clients_controller.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/team_controller.dart';

import '../support/fake_api.dart';

void main() {
  late FakeServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useFakeBackend();
    server = FakeServer();
  });

  group('clients', () {
    test('loads every page, with the foreman token', () async {
      server.on('GET', '/clients', (request) {
        final cursor = request.url.queryParameters['cursor'];
        return jsonResponse({
          'items': [_clientJson(cursor == null ? 'c-1' : 'c-2')],
          'page': {'nextCursor': cursor == null ? 'next' : null},
        });
      });
      final container = makeApiContainer(server: server, store: foremanStore());

      final clients = await container.read(clientsProvider.future);

      expect(clients.map((c) => c.id), ['c-1', 'c-2']);
      expect(clients.first.type, ClientType.company);
      expect(
        clients.first.preferredContactMethod,
        ClientContactMethod.whatsApp,
      );
      expect(clients.first.activeProjects, 3);
      expect(server.requests.map(bearerOf), everyElement('access-1'));
      expect(server.requests.first.url.queryParameters['limit'], '200');
    });

    test(
      'adding POSTs the editable fields and keeps the server copy',
      () async {
        server
          ..on('GET', '/clients', (_) => _page([_clientJson('c-1')]))
          ..on(
            'POST',
            '/clients',
            (_) => jsonResponse(_clientJson('srv-9'), 201),
          );
        final container = makeApiContainer(
          server: server,
          store: foremanStore(),
        );
        await container.read(clientsProvider.future);

        final created = await container
            .read(clientsProvider.notifier)
            .addClient(
              name: 'New Corp',
              activeProjects: 7,
              type: ClientType.publicInstitution,
              status: ClientStatus.active,
              preferredContactMethod: ClientContactMethod.email,
              notes: 'n',
              email: 'e@x.ro',
              phone: '07',
              addressLine1: 'Str. 1',
              city: 'Iasi',
              stateProvince: 'Iasi',
              zipCode: '700100',
              contactPerson: 'Ion',
            );

        final body = jsonBodyOf(server.requests.last);
        expect(body['type'], 'publicInstitution');
        expect(body['preferredContactMethod'], 'email');
        expect(body['state'], 'Iasi');
        expect(body.containsKey('activeProjects'), isFalse);
        expect(body.containsKey('id'), isFalse);
        expect(created.id, 'srv-9');
        expect(container.read(clientsProvider).requireValue.map((c) => c.id), [
          'c-1',
          'srv-9',
        ]);
      },
    );

    test('updating PATCHes the client and replaces it in place', () async {
      server
        ..on('GET', '/clients', (_) => _page([_clientJson('c-1')]))
        ..on(
          'PATCH',
          '/clients/c-1',
          (_) => jsonResponse(_clientJson('c-1', name: 'Renamed')),
        );
      final container = makeApiContainer(server: server, store: foremanStore());
      final before = (await container.read(clientsProvider.future)).single;

      await container
          .read(clientsProvider.notifier)
          .updateClient(
            id: 'c-1',
            name: 'Renamed',
            activeProjects: before.activeProjects,
            type: before.type,
            status: ClientStatus.inactive,
            preferredContactMethod: before.preferredContactMethod,
            notes: before.notes,
            email: before.email,
            phone: before.phone,
            addressLine1: before.addressLine1,
            city: before.city,
            stateProvince: before.state,
            zipCode: before.zipCode,
            contactPerson: before.contactPerson,
          );

      expect(server.requests.last.method, 'PATCH');
      expect(jsonBodyOf(server.requests.last)['status'], 'inactive');
      expect(
        container.read(clientsProvider).requireValue.single.name,
        'Renamed',
      );
    });

    test('a refused save throws and leaves the list alone', () async {
      server
        ..on('GET', '/clients', (_) => _page([_clientJson('c-1')]))
        ..on(
          'POST',
          '/clients',
          (_) => errorResponse(400, 'VALIDATION_FAILED', field: 'name'),
        );
      final container = makeApiContainer(server: server, store: foremanStore());
      await container.read(clientsProvider.future);

      await expectLater(
        container
            .read(clientsProvider.notifier)
            .addClient(
              name: '',
              activeProjects: 0,
              type: ClientType.individual,
              status: ClientStatus.active,
              preferredContactMethod: ClientContactMethod.phone,
              notes: '',
              email: '',
              phone: '',
              addressLine1: '',
              city: '',
              stateProvince: '',
              zipCode: '',
              contactPerson: '',
            ),
        throwsA(isA<ApiException>().having((e) => e.field, 'field', 'name')),
      );
      expect(container.read(clientsProvider).requireValue.length, 1);
    });

    test('nothing is fetched while signed out', () async {
      final container = makeApiContainer(server: server);

      expect(await container.read(clientsProvider.future), isEmpty);
      expect(server.requests, isEmpty);
    });

    test(
      'a different foreman signing in reloads, never showing the old list',
      () async {
        var reply = Completer<http.Response>()
          ..complete(_page([_clientJson('theirs')]));
        server
          ..on('GET', '/clients', (_) => reply.future)
          ..on(
            'POST',
            '/foreman/login',
            (_) => jsonResponse(loginBody(access: 'access-2', refresh: 'r-2')),
          );
        final container = makeApiContainer(
          server: server,
          store: foremanStore(userId: 'someone-else'),
        );
        final sub = container.listen(clientsProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(clientsProvider.future);

        reply = Completer<http.Response>();
        await container
            .read(authSessionProvider.notifier)
            .loginForeman(email: 'foreman@echipamea.local', password: 'pw');
        await pumpEventQueue();

        final reloading = container.read(clientsProvider);
        expect(reloading.isLoading, isTrue);
        expect(reloading.value!.single.id, 'theirs'); // Riverpod keeps it...
        expect(reloading.current, isNull); // ...but screens must not show it.

        reply.complete(_page([_clientJson('mine')]));
        final mine = await container.read(clientsProvider.future);
        expect(mine.single.id, 'mine');
        expect(bearerOf(server.requests.last), 'access-2');
      },
    );
  });

  group('employees', () {
    test('maps working days, location and the active flag', () async {
      server.on(
        'GET',
        '/employees',
        (_) => _page([
          _employeeJson('e-1', latitude: 46, longitude: 23.5),
          _employeeJson('e-2', isActive: false),
        ]),
      );
      final container = makeApiContainer(server: server, store: foremanStore());

      final team = await container.read(teamProvider.future);

      expect(team.first.workingDays, {1, 2, 3});
      expect(team.first.role, WorkerRole.plumber);
      expect(team.first.latitude, 46.0);
      expect(team.first.longitude, 23.5);
      expect(team.first.isActive, isTrue);
      expect(team.last.latitude, isNull);
      expect(team.last.isActive, isFalse);
    });

    test(
      'deactivating PATCHes isActive and keeps the known location',
      () async {
        server
          ..on(
            'GET',
            '/employees',
            (_) => _page([_employeeJson('e-1', latitude: 46, longitude: 23)]),
          )
          ..on(
            'PATCH',
            '/employees/e-1',
            (_) => jsonResponse(
              _employeeJson(
                'e-1',
                latitude: 46,
                longitude: 23,
                isActive: false,
              ),
            ),
          );
        final container = makeApiContainer(
          server: server,
          store: foremanStore(),
        );
        final employee = (await container.read(teamProvider.future)).single;

        await container
            .read(teamProvider.notifier)
            .updateEmployee(
              id: employee.id,
              name: employee.name,
              role: employee.role,
              email: employee.email,
              phone: employee.phone,
              workStartHour: employee.workStartHour,
              workEndHour: employee.workEndHour,
              workingDays: {3, 1, 2},
              isActive: false,
            );

        final body = jsonBodyOf(server.requests.last);
        expect(body['isActive'], isFalse);
        expect(body['workingDays'], [1, 2, 3]);
        expect(body['latitude'], 46);
        expect(
          container.read(teamProvider).requireValue.single.isActive,
          isFalse,
        );
      },
    );

    test('a new employee without a location sends none', () async {
      server
        ..on('GET', '/employees', (_) => _page([]))
        ..on(
          'POST',
          '/employees',
          (_) => jsonResponse(_employeeJson('e-9'), 201),
        );
      final container = makeApiContainer(server: server, store: foremanStore());
      await container.read(teamProvider.future);

      await container
          .read(teamProvider.notifier)
          .addEmployee(
            name: 'Nou',
            role: WorkerRole.helper,
            email: 'n@x.ro',
            phone: '07',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );

      final body = jsonBodyOf(server.requests.last);
      expect(body.containsKey('latitude'), isFalse);
      expect(body.containsKey('longitude'), isFalse);
      expect(body['role'], 'helper');
      expect(container.read(teamProvider).requireValue.single.id, 'e-9');
    });
  });
}

http.Response _page(List<Map<String, dynamic>> items) => jsonResponse({
  'items': items,
  'page': {'nextCursor': null},
});

Map<String, dynamic> _clientJson(String id, {String name = 'Cafe Luna'}) => {
  'id': id,
  'name': name,
  'activeProjects': 3,
  'type': 'company',
  'status': 'active',
  'preferredContactMethod': 'whatsApp',
  'notes': '',
  'email': 'contact@cafeluna.example.com',
  'phone': '+40 756 333 444',
  'addressLine1': 'Piata Unirii 3',
  'city': 'Timisoara',
  'state': 'Timis',
  'zipCode': '300085',
  'contactPerson': 'Ana Moldovan',
  'createdAt': '2026-10-01T08:00:00.000Z',
  'updatedAt': '2026-10-01T08:00:00.000Z',
};

Map<String, dynamic> _employeeJson(
  String id, {
  num? latitude,
  num? longitude,
  bool isActive = true,
}) => {
  'id': id,
  'name': 'Mihai S.',
  'role': 'plumber',
  'email': 'mihai@example.com',
  'phone': '+40 722 000 222',
  'workStartHour': 8,
  'workEndHour': 17,
  'workingDays': [1, 2, 3],
  'latitude': latitude,
  'longitude': longitude,
  'isActive': isActive,
};
