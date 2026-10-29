import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/features/foreman/presentation/providers/day_sequences_controller.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';

import '../support/fake_api.dart';

const _day = '2026-04-14';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Keeps the auto-disposed day alive for the test and returns its notifier.
  Future<DaySequencesNotifier> watchDay(ProviderContainer container) async {
    final sub = container.listen(daySequencesProvider(_day), (_, _) {});
    addTearDown(sub.close);
    await container.read(daySequencesProvider(_day).future);
    return container.read(daySequencesProvider(_day).notifier);
  }

  DaySequences day(ProviderContainer container) =>
      container.read(daySequencesProvider(_day)).requireValue;

  group('mock mode', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test(
      'suggests each worker the phases whose window covers the day',
      () async {
        await watchDay(container);

        final andrei = day(container).of(projectId: 'p1', workerId: 'e1');
        expect(andrei.orderedPhaseIds, ['p1_phase_1']);
        expect(andrei.suggestedPhaseIds, ['p1_phase_1']);
        expect(andrei.isManual, isFalse);
        expect(
          day(container).of(projectId: 'p2', workerId: 'e3').orderedPhaseIds,
          ['p2_phase_1'],
        );
        // Mihai's only phase ended on the 12th.
        expect(
          day(container).of(projectId: 'p3', workerId: 'e2').orderedPhaseIds,
          isEmpty,
        );
      },
    );

    test('a saved order wins, and reset goes back to the suggestion', () async {
      final notifier = await watchDay(container);

      await notifier.save(
        projectId: 'p1',
        workerId: 'e1',
        orderedPhaseIds: ['p1_phase_2', 'p1_phase_1'],
      );
      var andrei = day(container).of(projectId: 'p1', workerId: 'e1');
      expect(andrei.orderedPhaseIds, ['p1_phase_2', 'p1_phase_1']);
      expect(andrei.isManual, isTrue);

      await notifier.reset(projectId: 'p1', workerId: 'e1');
      andrei = day(container).of(projectId: 'p1', workerId: 'e1');
      expect(andrei.orderedPhaseIds, ['p1_phase_1']);
      expect(andrei.isManual, isFalse);
    });

    test(
      'a saved order keeps newly suggested phases and drops deleted ones',
      () async {
        final notifier = await watchDay(container);
        await notifier.save(
          projectId: 'p1',
          workerId: 'e1',
          orderedPhaseIds: ['p1_phase_2'],
        );
        expect(
          day(container).of(projectId: 'p1', workerId: 'e1').orderedPhaseIds,
          ['p1_phase_2', 'p1_phase_1'],
        );

        await container
            .read(projectsProvider.notifier)
            .removePhase(projectId: 'p1', phaseId: 'p1_phase_2');
        // The day reloads because its projects changed.
        await pumpEventQueue();
        await container.read(daySequencesProvider(_day).future);

        expect(
          day(container).of(projectId: 'p1', workerId: 'e1').orderedPhaseIds,
          ['p1_phase_1'],
        );
      },
    );
  });

  group('with a backend', () {
    late FakeServer server;

    setUp(() {
      useFakeBackend();
      server = FakeServer()
        ..on('GET', '/projects', (_) => jsonResponse(_emptyPage))
        ..on(
          'GET',
          '/sequences',
          (_) => jsonResponse({
            'dayKey': _day,
            'sequences': [
              {
                'projectId': 'p-1',
                'dayKey': _day,
                'workerId': 'e-1',
                'orderedPhaseIds': ['ph-2', 'ph-1'],
                'suggestedPhaseIds': ['ph-1'],
                'isManual': true,
              },
            ],
            'phaseNames': {'ph-1': 'Demolition', 'ph-2': 'Finishing'},
          }),
        );
    });

    test('loads the whole day in one request', () async {
      final container = makeApiContainer(server: server, store: foremanStore());
      await watchDay(container);

      final sequence = day(container).of(projectId: 'p-1', workerId: 'e-1');
      expect(sequence.orderedPhaseIds, ['ph-2', 'ph-1']);
      expect(sequence.suggestedPhaseIds, ['ph-1']);
      expect(sequence.isManual, isTrue);
      final get = server.requests.firstWhere((r) => r.url.path == '/sequences');
      expect(get.url.queryParameters['day'], _day);
    });

    test('saving PUTs the order for that day, resetting DELETEs it', () async {
      server
        ..on('PUT', '/projects/p-1/workers/e-1/sequence', (_) {
          return jsonResponse({
            'projectId': 'p-1',
            'dayKey': _day,
            'workerId': 'e-1',
            'orderedPhaseIds': ['ph-1'],
            'suggestedPhaseIds': ['ph-1'],
            'isManual': true,
          });
        })
        ..on('DELETE', '/projects/p-1/workers/e-1/sequence', (_) => http204());
      final container = makeApiContainer(server: server, store: foremanStore());
      final notifier = await watchDay(container);

      await notifier.save(
        projectId: 'p-1',
        workerId: 'e-1',
        orderedPhaseIds: ['ph-1'],
      );
      final put = server.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.url.queryParameters['day'], _day);
      expect(jsonBodyOf(put), {
        'orderedPhaseIds': ['ph-1'],
      });

      await notifier.reset(projectId: 'p-1', workerId: 'e-1');
      final delete = server.requests.firstWhere((r) => r.method == 'DELETE');
      expect(delete.url.queryParameters['day'], _day);
      // Each change reloads the day.
      expect(server.count('GET', '/sequences'), 3);
    });
  });
}

const _emptyPage = {
  'items': [],
  'page': {'nextCursor': null},
};
