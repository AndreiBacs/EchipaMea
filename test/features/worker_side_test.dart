import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/auth/session_controller.dart';
import 'package:echipa_mea/src/core/domain/entities/worker_role.dart';
import 'package:echipa_mea/src/core/network/api_exception.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';
import 'package:echipa_mea/src/features/worker/data/worker_repository.dart';
import 'package:echipa_mea/src/features/worker/presentation/providers/worker_assigned_projects_provider.dart';
import 'package:echipa_mea/src/features/worker/presentation/providers/worker_day_provider.dart';
import 'package:echipa_mea/src/features/worker/presentation/providers/worker_me_provider.dart';

import '../support/fake_api.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mock mode', () {
    ProviderContainer signedIn({
      String employeeId = 'e1',
      String employeeName = 'Andrei D.',
    }) => makeApiContainer(
      store: workerStore(
        employeeId: employeeId,
        employeeName: employeeName,
        access: 'mock-worker-session-1',
      ),
    );

    test('lists the unfinished projects assigned to the worker', () async {
      final container = signedIn();
      final projects = await container.read(
        workerAssignedProjectsProvider.future,
      );
      expect(projects.map((p) => p.id), ['p1']);
    });

    test('falls back to the display name for projects without ids', () async {
      // Not on the roster, but named on p1's worker list.
      final container = signedIn(employeeId: 'e9', employeeName: 'vlad p.');
      final projects = await container.read(
        workerAssignedProjectsProvider.future,
      );
      expect(projects.map((p) => p.id), ['p1']);
    });

    test('nothing is listed with no worker signed in', () async {
      final container = makeApiContainer();
      expect(await container.read(workerAssignedProjectsProvider.future), []);
      expect(await container.read(workerMeProvider.future), isNull);
    });

    test('reads the worker record from the roster', () async {
      final container = signedIn();
      final me = await container.read(workerMeProvider.future);
      expect(me!.name, 'Andrei D.');
      expect(me.workStartHour, 7);
      expect(me.workingDays, {1, 2, 3, 4, 5});
    });

    test(
      'submitting a phase moves it, for the worker and the foreman',
      () async {
        final container = signedIn();
        await container.read(workerAssignedProjectsProvider.future);
        await container.read(projectsProvider.future);

        await container
            .read(workerAssignedProjectsProvider.notifier)
            .submitPhase(projectId: 'p1', phaseId: 'p1_phase_1');

        final mine = container.read(workerAssignedProjectsProvider).value!;
        expect(mine.single.phases.first.status, PhaseStatus.pendingReview);
        final foremanCopy = await container.read(projectsProvider.future);
        expect(
          foremanCopy.firstWhere((p) => p.id == 'p1').phases.first.status,
          PhaseStatus.pendingReview,
        );
      },
    );

    test("the worker's day holds only their own sequences", () async {
      final container = signedIn();
      final sub = container.listen(workerDayProvider('2026-04-14'), (_, _) {});
      addTearDown(sub.close);

      final day = await container.read(workerDayProvider('2026-04-14').future);

      expect(day.sequences.map((s) => s.workerId), everyElement('e1'));
      expect(day.of(projectId: 'p1', workerId: 'e1').orderedPhaseIds, [
        'p1_phase_1',
      ]);
    });
  });

  group('with a backend', () {
    late FakeServer server;

    setUp(() {
      useFakeBackend();
      server = FakeServer()
        ..on('GET', '/worker/projects', (_) => jsonResponse(_projects()))
        ..on(
          'GET',
          '/worker/me',
          (_) => jsonResponse({
            'employeeId': 'e-1',
            'name': 'Andrei D.',
            'role': 'electrician',
            'email': 'andrei@example.com',
            'phone': '+40 721 000 111',
            'workStartHour': 7,
            'workEndHour': 16,
            'workingDays': [1, 2, 3, 4, 5],
            'latitude': 46.77,
            'longitude': null,
            'companyId': 'demo-company',
            'companyName': 'Demo',
          }),
        );
    });

    ProviderContainer signedIn() => makeApiContainer(
      server: server,
      store: workerStore(employeeId: 'e-1'),
    );

    test('lists projects with the worker token, never the roster', () async {
      final container = signedIn();

      final projects = await container.read(
        workerAssignedProjectsProvider.future,
      );

      expect(projects.single.id, 'p-1');
      expect(server.count('GET', '/worker/projects'), 1);
      expect(server.count('GET', '/projects'), 0);
      expect(server.count('GET', '/employees'), 0);
      expect(
        bearerOf(
          server.requests.firstWhere((r) => r.url.path == '/worker/projects'),
        ),
        'worker-access-1',
      );
    });

    test('reads the worker record from /worker/me', () async {
      final container = signedIn();

      final me = await container.read(workerMeProvider.future);

      expect(me!.id, 'e-1');
      expect(me.role, WorkerRole.electrician);
      expect(me.workEndHour, 16);
      expect(me.latitude, 46.77);
      expect(me.longitude, isNull);
    });

    test('announcing arrival POSTs the project', () async {
      server.on(
        'POST',
        '/worker/arrivals',
        (_) => jsonResponse({'id': 'a-1', 'duplicate': false}, 201),
      );
      final container = signedIn();
      await container.read(workerAssignedProjectsProvider.future);

      final repository = container.read(workerRepositoryProvider);
      await repository.announceArrival(
        (await container.read(sessionProvider.future))!,
        'p-1',
      );

      final body = jsonBodyOf(server.requests.last);
      expect(body['projectId'], 'p-1');
      expect(DateTime.parse(body['arrivedAt'] as String).isUtc, isTrue);
    });

    test('submitting a phase POSTs submit and refetches the project', () async {
      server
        ..on(
          'POST',
          '/projects/p-1/phases/ph-1/submit',
          (_) => jsonResponse({'id': 'ph-1'}),
        )
        ..on(
          'GET',
          '/worker/projects/p-1',
          (_) => jsonResponse(_project(phaseStatus: 'pendingReview')),
        );
      final container = signedIn();
      await container.read(workerAssignedProjectsProvider.future);

      await container
          .read(workerAssignedProjectsProvider.notifier)
          .submitPhase(projectId: 'p-1', phaseId: 'ph-1');

      final submit = server.requests.firstWhere((r) => r.method == 'POST');
      expect(bearerOf(submit), 'worker-access-1');
      expect(jsonBodyOf(submit), isEmpty);
      expect(
        container
            .read(workerAssignedProjectsProvider)
            .value!
            .single
            .phases
            .single
            .status,
        PhaseStatus.pendingReview,
      );
    });

    test('a refused submit throws and changes nothing', () async {
      server.on(
        'POST',
        '/projects/p-1/phases/ph-1/submit',
        (_) => errorResponse(409, 'PHASE_INVALID_TRANSITION'),
      );
      final container = signedIn();
      await container.read(workerAssignedProjectsProvider.future);

      await expectLater(
        container
            .read(workerAssignedProjectsProvider.notifier)
            .submitPhase(projectId: 'p-1', phaseId: 'ph-1'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
      expect(
        container
            .read(workerAssignedProjectsProvider)
            .value!
            .single
            .phases
            .single
            .status,
        PhaseStatus.inProgress,
      );
    });

    test("the worker's day comes from /workers/:id/sequence", () async {
      server.on(
        'GET',
        '/workers/e-1/sequence',
        (_) => jsonResponse({
          'dayKey': '2026-04-14',
          'sequences': [
            {
              'projectId': 'p-1',
              'dayKey': '2026-04-14',
              'workerId': 'e-1',
              'orderedPhaseIds': ['ph-1'],
              'suggestedPhaseIds': ['ph-1'],
              'isManual': false,
            },
          ],
        }),
      );
      final container = signedIn();
      final sub = container.listen(workerDayProvider('2026-04-14'), (_, _) {});
      addTearDown(sub.close);

      final day = await container.read(workerDayProvider('2026-04-14').future);

      expect(day.of(projectId: 'p-1', workerId: 'e-1').orderedPhaseIds, [
        'ph-1',
      ]);
      final get = server.requests.firstWhere(
        (r) => r.url.path == '/workers/e-1/sequence',
      );
      expect(get.url.queryParameters['day'], '2026-04-14');
    });
  });
}

Map<String, dynamic> _projects() => {
  'items': [_project()],
  'page': {'nextCursor': null},
};

Map<String, dynamic> _project({String phaseStatus = 'inProgress'}) => {
  'id': 'p-1',
  'name': 'Main Street 15',
  'clientId': 'c-1',
  'status': 'inProgress',
  'workers': ['Andrei D.'],
  'assignedEmployeeIds': ['e-1'],
  'useClientAddress': true,
  'addressLine1': 'Str. Victoriei 12',
  'city': 'Bucuresti',
  'state': 'Bucuresti',
  'zipCode': '010072',
  'phases': [
    {
      'id': 'ph-1',
      'name': 'Demolition',
      'startDate': '2026-04-13',
      'endDate': '2026-04-16',
      'description': '',
      'status': phaseStatus,
      'assignedEmployeeIds': ['e-1'],
      'submittedByEmployeeIds': [],
      'workInstructions': [],
    },
  ],
};
