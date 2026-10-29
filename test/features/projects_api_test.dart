import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';

import '../support/fake_api.dart';

void main() {
  late FakeServer server;
  late Map<String, dynamic> stored;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useFakeBackend();
    stored = _projectJson();
    server = FakeServer()
      ..on('GET', '/projects', (_) => _page([stored]))
      ..on('GET', '/projects/p-1', (_) => jsonResponse(stored));
  });

  Future<ProjectsNotifier> load(ProviderContainer container) async {
    await container.read(projectsProvider.future);
    return container.read(projectsProvider.notifier);
  }

  test('loads projects with phases, mapping dates and media', () async {
    final container = makeApiContainer(server: server, store: foremanStore());

    final project = (await container.read(projectsProvider.future)).single;

    expect(server.requests.single.url.queryParameters['include'], 'phases');
    expect(project.status, ProjectStatus.inProgress);
    expect(project.workers, ['Andrei D.']);
    final phase = project.phases.first;
    expect(phase.startDate, DateTime(2026, 4, 13));
    expect(phase.endDate, DateTime(2026, 4, 16));
    expect(phase.status, PhaseStatus.pendingReview);
    expect(phase.submittedAt, DateTime.utc(2026, 4, 14, 16).toLocal());
    expect(phase.reviewedAt, isNull);
    expect(phase.workInstructions.single.photoMediaIds, ['m-photo']);
    expect(phase.workInstructions.single.audioMediaIds, ['m-audio']);
  });

  test(
    'creating sends the phases inline, as day keys and without ids',
    () async {
      server.on('POST', '/projects', (_) => jsonResponse(stored, 201));
      final container = makeApiContainer(server: server, store: foremanStore());
      final notifier = await load(container);

      await notifier.addProject(
        name: 'Bathroom',
        clientId: 'c-1',
        status: ProjectStatus.planned,
        workers: const ['ignored'],
        assignedEmployeeIds: const ['e-1'],
        addressLine1: 'Str. 1',
        city: 'Cluj',
        stateProvince: 'Cluj',
        zipCode: '400001',
        phases: [
          ProjectPhase(
            id: 'draft_1',
            name: 'Tiles',
            startDate: DateTime(2026, 5, 4, 18),
            endDate: DateTime(2026, 5, 6),
            assignedEmployeeIds: const ['e-1'],
            status: PhaseStatus.notStarted,
            workInstructions: const [
              PhaseWorkInstruction(id: 'wi_1', text: 'Seal first'),
            ],
          ),
        ],
      );

      final body = jsonBodyOf(server.requests.last);
      expect(body.containsKey('status'), isFalse);
      expect(body.containsKey('workers'), isFalse);
      expect(body['assignedEmployeeIds'], ['e-1']);
      final phase = (body['phases'] as List).single as Map<String, dynamic>;
      expect(phase.containsKey('id'), isFalse);
      expect(phase['startDate'], '2026-05-04');
      expect(phase['endDate'], '2026-05-06');
      expect(phase['workInstructions'], [
        {'text': 'Seal first', 'photoMediaIds': [], 'audioMediaIds': []},
      ]);
    },
  );

  test('saving a project PATCHes its fields only, then closes it', () async {
    server
      ..on('PATCH', '/projects/p-1', (_) => jsonResponse(stored))
      ..on('POST', '/projects/p-1/done', (_) {
        stored = {...stored, 'status': 'done'};
        return jsonResponse(stored);
      });
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);
    final project = notifier.findById('p-1')!;

    final saved = await notifier.updateProject(
      id: project.id,
      name: 'Renamed',
      clientId: project.clientId,
      status: ProjectStatus.done,
      workers: project.workers,
      addressLine1: project.addressLine1,
      city: project.city,
      stateProvince: project.state,
      zipCode: project.zipCode,
    );

    final patch = server.requests.firstWhere((r) => r.method == 'PATCH');
    expect(jsonBodyOf(patch).containsKey('phases'), isFalse);
    expect(jsonBodyOf(patch)['name'], 'Renamed');
    expect(server.count('POST', '/projects/p-1/done'), 1);
    expect(saved.status, ProjectStatus.done);
    expect(notifier.findById('p-1')!.status, ProjectStatus.done);
  });

  test('saving a closed project with another status reopens it', () async {
    stored = {...stored, 'status': 'done'};
    server
      ..on('PATCH', '/projects/p-1', (_) => jsonResponse(stored))
      ..on('POST', '/projects/p-1/reopen', (_) {
        stored = {...stored, 'status': 'inProgress'};
        return jsonResponse(stored);
      });
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);
    final project = notifier.findById('p-1')!;

    final saved = await notifier.updateProject(
      id: project.id,
      name: project.name,
      clientId: project.clientId,
      status: ProjectStatus.inProgress,
      workers: project.workers,
      addressLine1: project.addressLine1,
      city: project.city,
      stateProvince: project.state,
      zipCode: project.zipCode,
    );

    expect(server.count('POST', '/projects/p-1/reopen'), 1);
    expect(saved.status, ProjectStatus.inProgress);
  });

  test('a phase change refetches the project for its new status', () async {
    server.on('POST', '/projects/p-1/phases', (request) {
      stored = {
        ...stored,
        'phases': [
          ...stored['phases'] as List,
          {..._phaseJson('ph-new'), ...jsonBodyOf(request)},
        ],
      };
      return jsonResponse(_phaseJson('ph-new'), 201);
    });
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);

    await notifier.addPhase(
      projectId: 'p-1',
      name: 'Paint',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 2),
      assignedEmployeeIds: const [],
    );

    expect(server.requests.last.url.path, '/projects/p-1');
    expect(notifier.findById('p-1')!.phases.map((p) => p.id), [
      'ph-1',
      'ph-new',
    ]);
  });

  test(
    'editing a phase sends its server media back, so none is lost',
    () async {
      server.on(
        'PATCH',
        '/projects/p-1/phases/ph-1',
        (_) => jsonResponse(_phaseJson('ph-1')),
      );
      final container = makeApiContainer(server: server, store: foremanStore());
      final notifier = await load(container);
      final phase = notifier.findById('p-1')!.phases.single;

      await notifier.updatePhase(
        projectId: 'p-1',
        phaseId: phase.id,
        name: 'Demolition, phase 1',
        startDate: phase.startDate,
        endDate: phase.endDate,
        assignedEmployeeIds: phase.assignedEmployeeIds,
        workInstructions: [
          phase.workInstructions.single.copyWith(text: 'Cut power first'),
        ],
      );

      final patch = server.requests.firstWhere((r) => r.method == 'PATCH');
      final body = jsonBodyOf(patch);
      expect(body['name'], 'Demolition, phase 1');
      expect(body['startDate'], '2026-04-13');
      expect(body['workInstructions'], [
        {
          'text': 'Cut power first',
          'photoMediaIds': ['m-photo'],
          'audioMediaIds': ['m-audio'],
        },
      ]);
    },
  );

  test('reviewing sends no reviewer and keeps the returned project', () async {
    server.on('POST', '/projects/p-1/phases/ph-1/review', (_) {
      return jsonResponse({
        ...stored,
        'status': 'done',
        'phases': [
          {..._phaseJson('ph-1'), 'status': 'done'},
        ],
      });
    });
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);

    await notifier.reviewPhase(
      projectId: 'p-1',
      phaseId: 'ph-1',
      approved: true,
    );

    expect(jsonBodyOf(server.requests.last), {'approved': true});
    expect(notifier.findById('p-1')!.status, ProjectStatus.done);
  });

  test('a reported phase is fetched, never submitted by the foreman', () async {
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);
    stored = {...stored, 'name': 'Fetched again'};

    await notifier.submitPhaseForReview(
      projectId: 'p-1',
      phaseId: 'ph-1',
      employeeId: 'e-1',
    );

    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
    expect(notifier.findById('p-1')!.name, 'Fetched again');
  });

  test('removing a phase DELETEs it and refetches the project', () async {
    server.on('DELETE', '/projects/p-1/phases/ph-1', (_) {
      stored = {...stored, 'status': 'planned', 'phases': []};
      return http204();
    });
    final container = makeApiContainer(server: server, store: foremanStore());
    final notifier = await load(container);

    await notifier.removePhase(projectId: 'p-1', phaseId: 'ph-1');

    expect(notifier.findById('p-1')!.phases, isEmpty);
    expect(notifier.findById('p-1')!.status, ProjectStatus.planned);
  });
}

http.Response _page(List<Map<String, dynamic>> items) => jsonResponse({
  'items': items,
  'page': {'nextCursor': null},
});

Map<String, dynamic> _projectJson() => {
  'id': 'p-1',
  'name': 'Renovation - Main Street 15',
  'clientId': 'c-1',
  'status': 'inProgress',
  'workers': ['Andrei D.'],
  'assignedEmployeeIds': ['e-1'],
  'useClientAddress': true,
  'addressLine1': 'Str. Victoriei 12',
  'city': 'Bucuresti',
  'state': 'Bucuresti',
  'zipCode': '010072',
  'latitude': 46.7723,
  'longitude': 23.6236,
  'closedAt': null,
  'phases': [_phaseJson('ph-1')],
};

Map<String, dynamic> _phaseJson(String id) => {
  'id': id,
  'name': 'Demolition',
  'startDate': '2026-04-13',
  'endDate': '2026-04-16',
  'description': '',
  'status': 'pendingReview',
  'assignedEmployeeIds': ['e-1'],
  'submittedAt': '2026-04-14T16:00:00.000Z',
  'submittedByEmployeeIds': ['e-1'],
  'reviewedAt': null,
  'reviewedByForemanId': null,
  'reviewNotes': null,
  'workInstructions': [
    {
      'id': 'wi-1',
      'text': 'Disconnect utilities before starting.',
      'photos': [
        {
          'id': 'm-photo',
          'url': '/media/m-photo/content',
          'contentType': 'image/jpeg',
        },
      ],
      'audio': [
        {
          'id': 'm-audio',
          'url': '/media/m-audio/content',
          'contentType': 'audio/m4a',
        },
      ],
    },
  ],
};
