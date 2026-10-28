import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/core/config/app_env.dart';
import 'package:echipa_mea/src/features/foreman/application/foreman_notifications_coordinator.dart';
import 'package:echipa_mea/src/features/foreman/domain/entities/foreman_notification.dart';

import '../support/fake_api.dart';

void main() {
  late FakeServer server;
  var unread = 2;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useFakeBackend();
    unread = 2;
    server = FakeServer()
      ..on(
        'GET',
        '/notifications',
        (_) => jsonResponse({
          'items': [
            {
              'id': 'n-2',
              'kind': 'workerReportSubmitted',
              'payload': {
                'employeeName': 'Andrei D.',
                'projectName': 'Main Street 15',
                'phaseName': 'Demolition',
                'photoCount': 2,
              },
              'projectId': 'p-1',
              'phaseId': 'ph-1',
              'employeeId': 'e-1',
              'occurredAt': '2026-04-14T16:00:00.000Z',
              'createdAt': '2026-04-14T16:00:01.000Z',
              'readAt': unread == 0 ? '2026-04-14T17:00:00.000Z' : null,
            },
            {
              'id': 'n-1',
              'kind': 'somethingNew',
              'payload': {},
              'occurredAt': '2026-04-14T08:00:00.000Z',
              'createdAt': '2026-04-14T08:00:00.000Z',
              'readAt': null,
            },
          ],
          'page': {'nextCursor': null},
          'unreadCount': unread,
        }),
      );
  });

  Future<ForemanNotificationsState> load(ProviderContainer container) =>
      container.read(foremanNotificationsProvider.future);

  test('loads the newest notifications and the unread count', () async {
    final container = makeApiContainer(server: server, store: foremanStore());

    final state = await load(container);

    expect(server.requests.single.url.queryParameters['limit'], '50');
    expect(state.unreadCount, 2);
    final report = state.items.first;
    expect(report.kind, ForemanNotificationKind.workerReportSubmitted);
    expect(report.employeeName, 'Andrei D.');
    expect(report.projectName, 'Main Street 15');
    expect(report.phaseName, 'Demolition');
    expect(report.projectId, 'p-1');
    expect(report.occurredAt, DateTime.utc(2026, 4, 14, 16).toLocal());
    expect(report.isRead, isFalse);
    expect(state.items.last.kind, ForemanNotificationKind.other);
  });

  test(
    'opening the list clears the badge at once, then tells the server',
    () async {
      server.on('POST', '/notifications/read-all', (_) {
        unread = 0;
        return jsonResponse({'updated': 2});
      });
      final container = makeApiContainer(server: server, store: foremanStore());
      await load(container);

      final marking = container
          .read(foremanNotificationsProvider.notifier)
          .markAllRead();
      expect(
        container.read(foremanNotificationsProvider).value!.unreadCount,
        0,
      );
      await marking;

      expect(server.count('POST', '/notifications/read-all'), 1);
      final state = container.read(foremanNotificationsProvider).value!;
      expect(state.unreadCount, 0);
      expect(state.items.first.isRead, isTrue);
    },
  );

  test('a failed refresh keeps the list already shown', () async {
    final container = makeApiContainer(server: server, store: foremanStore());
    final before = await load(container);
    server.on(
      'GET',
      '/notifications',
      (_) => errorResponse(503, 'UNAVAILABLE'),
    );

    await container.read(foremanNotificationsProvider.notifier).refresh();

    expect(
      container.read(foremanNotificationsProvider).value!.items,
      before.items,
    );
  });

  test('nothing is fetched while signed out', () async {
    final container = makeApiContainer(server: server);

    final state = await load(container);

    expect(state.items, isEmpty);
    expect(server.requests, isEmpty);
  });

  test('mock mode has no notifications', () async {
    AppEnv.authApiBaseUrl = '';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await load(container);

    expect(state.items, isEmpty);
    expect(state.unreadCount, 0);
  });
}
