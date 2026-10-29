// End-to-end: the real app, driven through its UI, against a real server.
//
// Start the server first (it resets and seeds the e2e test database):
//   cd server && npm run e2e:app-server
// then, from the repo root:
//   flutter test integration_test -d windows        (or -d linux)
// or run scripts/e2e_app.sh, which does both. E2E_API_BASE_URL
// (--dart-define) points at a server elsewhere; default 127.0.0.1:3100.
//
// The cross-system steps go through the UI: foreman sign-in, the login code
// shown to the foreman and typed by the worker, arrival, the report, the live
// badge and approval. Data setup (a client, an employee, a project) goes
// through the app's own notifiers, which hit the same server; the forms
// themselves are covered by widget tests.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echipa_mea/src/app.dart';
import 'package:echipa_mea/src/core/auth/auth_session_controller.dart';
import 'package:echipa_mea/src/core/auth/session_controller.dart';
import 'package:echipa_mea/src/core/auth/token_store.dart';
import 'package:echipa_mea/src/core/config/app_env.dart';
import 'package:echipa_mea/src/core/domain/entities/worker_role.dart';
import 'package:echipa_mea/src/core/i18n/app_localizations.dart';
import 'package:echipa_mea/src/core/i18n/locale_controller.dart';
import 'package:echipa_mea/src/core/network/api_client.dart';
import 'package:echipa_mea/src/core/routing/app_router.dart';
import 'package:echipa_mea/src/features/foreman/application/foreman_notifications_coordinator.dart';
import 'package:echipa_mea/src/features/foreman/domain/entities/foreman_notification.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/clients_controller.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/projects_controller.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/team_controller.dart';
import 'package:echipa_mea/src/features/worker/application/worker_reports_api_provider.dart';
import 'package:echipa_mea/src/features/worker/presentation/providers/worker_assigned_projects_provider.dart';

const _apiBase = String.fromEnvironment(
  'E2E_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3100',
);

final _en = AppLocalizations(const Locale('en'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Both sessions live here for the whole run, so "restart" is a fresh app
  // on the same store, and the developer's real keychain is never touched.
  final store = MemoryTokenStore();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    AppEnv.initialize();
    AppEnv.authApiBaseUrl = _apiBase;
    AppEnv.foremanNotificationsWsUrl =
        '${_apiBase.replaceFirst('http', 'ws')}/ws/foreman-notifications';
    // Telemetry needs GPS, which a CI machine does not have; not under test.
    AppEnv.workerTelemetryWsUrl = '';
    AppEnv.workerReportsApiUrl = '';
    SharedPreferences.setMockInitialValues({
      'app_initial_setup_completed': true,
    });
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: apiRetry,
        overrides: [tokenStoreProvider.overrideWithValue(store)],
        child: const EchipaMeaApp(),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EchipaMeaApp)),
    );
    container.read(localeProvider.notifier).setLocale(const Locale('en'));
    await tester.pump();
    return container;
  }

  testWidgets('foreman and worker, end to end', (tester) async {
    var app = await pumpApp(tester);
    GoRouter router() => app.read(appRouterProvider);

    // 1. The foreman signs in through the login screen.

    step('1');
    await pumpUntilFound(tester, find.text(_en.loginAsForeman));
    await tester.enterText(
      find.widgetWithText(TextField, _en.profileEmailLabel),
      'foreman@echipamea.local',
    );
    await tester.enterText(
      find.widgetWithText(TextField, _en.password),
      'foreman123',
    );
    await tester.tap(find.text(_en.loginAsForeman));
    await pumpUntil(
      tester,
      () => app.read(authSessionProvider).value != null,
      reason: 'foreman signed in',
    );

    // 2. Data setup, through the app's notifiers against the server.

    step('2');
    final day = DateTime.now();
    await within(app.read(clientsProvider.future));
    await app
        .read(clientsProvider.notifier)
        .addClient(
          name: 'E2E Client',
          activeProjects: 0,
          type: ClientType.company,
          status: ClientStatus.active,
          preferredContactMethod: ClientContactMethod.email,
          notes: '',
          email: 'e2e@example.com',
          phone: '+40 700 000 999',
          addressLine1: 'Str. Testului 1',
          city: 'Cluj-Napoca',
          stateProvince: 'Cluj',
          zipCode: '400001',
          contactPerson: 'E2E',
        );
    await within(app.read(teamProvider.future));
    await app
        .read(teamProvider.notifier)
        .addEmployee(
          name: 'Zeno E2E',
          role: WorkerRole.helper,
          email: 'zeno@example.com',
          phone: '+40 700 000 998',
          workStartHour: 7,
          workEndHour: 16,
          workingDays: {1, 2, 3, 4, 5},
        );
    await within(app.read(projectsProvider.future));
    final project = await app
        .read(projectsProvider.notifier)
        .addProject(
          name: 'E2E Bathroom',
          clientId: 'c1',
          status: ProjectStatus.planned,
          workers: const [],
          assignedEmployeeIds: const ['e1'],
          addressLine1: 'Str. Victoriei 12',
          city: 'Bucuresti',
          stateProvince: 'Bucuresti',
          zipCode: '010072',
          phases: [
            ProjectPhase(
              id: '',
              name: 'Tiles',
              startDate: day.subtract(const Duration(days: 1)),
              endDate: day.add(const Duration(days: 1)),
              assignedEmployeeIds: const ['e1'],
              status: PhaseStatus.notStarted,
            ),
          ],
        );
    final phase = project.phases.single;

    // 3. The foreman shows Andrei's login code (Team tab, QR dialog).

    step('3');
    router().go('/foreman/team');
    await pumpUntilFound(tester, find.byTooltip(_en.generateLoginQrTooltip));
    await tester.tap(find.byTooltip(_en.generateLoginQrTooltip).first);
    await pumpUntilFound(tester, find.text(_en.employeeLoginCodeShow));
    await tester.tap(find.text(_en.employeeLoginCodeShow));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('employee-login-code')),
    );
    final code = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('employee-login-code')),
        )
        .data!;
    await tester.tap(find.text(_en.close));
    await tester.pump();

    // 4. The worker types it on the connect page.

    step('4');
    router().go('/worker/connect');
    final codeField = find.byKey(const ValueKey('worker-login-code-field'));
    await pumpUntilFound(tester, codeField);
    // On web and mobile the camera scanner sits above the field.
    await tester.ensureVisible(codeField);
    await tester.enterText(codeField, code);
    await tester.ensureVisible(find.text(_en.workerConnectWithCode));
    await tester.tap(find.text(_en.workerConnectWithCode));
    await pumpUntil(
      tester,
      () => app.read(sessionProvider).value?.employeeId == 'e1',
      reason: 'worker signed in',
    );

    // 5. The job shows up for the worker, who announces arrival.

    step('5');
    router().go('/worker/project/${project.id}');
    final arrive = find.text(_en.workerAnnounceArrival);
    await pumpUntilFound(tester, arrive);
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await pumpUntilFound(tester, find.text(_en.workerArrivalSent));

    // 6. The worker reports on the phase: no photos, no memo, a text.

    step('6');
    final unreadBefore = (await app.read(
      foremanNotificationsProvider.future,
    )).unreadCount;
    router().go('/worker/project/${project.id}/phase/${phase.id}/report');
    await pumpUntilFound(tester, find.text(_en.setupNext));
    await tester.tap(find.text(_en.setupNext));
    await settle(tester);
    await tester.tap(find.text(_en.setupNext));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Tiles laid.');
    await tester.tap(find.text(_en.workerReportSubmit));
    await pumpUntilFound(tester, find.text(_en.workerReportSubmitted));

    // 7. The foreman's badge rises live, over the socket.

    step('7');
    await pumpUntil(
      tester,
      () => unread(app) > unreadBefore,
      reason: 'live notification for the report',
    );
    final reportNotice = app
        .read(foremanNotificationsProvider)
        .value!
        .items
        .firstWhere(
          (n) => n.kind == ForemanNotificationKind.workerReportSubmitted,
        );
    expect(reportNotice.projectId, project.id);

    // 8. The phase is pending review; approving it finishes the project.

    step('8');
    router().go('/foreman/projects/${project.id}/edit?tab=phases');
    await pumpUntilFound(tester, find.byTooltip(_en.approve));
    await tester.tap(find.byTooltip(_en.approve));
    await pumpUntil(
      tester,
      () =>
          app.read(projectsProvider.notifier).findById(project.id)?.status ==
          ProjectStatus.done,
      reason: 'project done after approval',
    );

    // 9. A dropped socket comes back: a report sent while it is down still

    step('9');
    // reaches the list, by the reconnect or by the refetch after it.
    final closed =
        await app.read(foremanApiProvider).post('/__e2e/realtime/drop-foremen')
            as Json;
    expect(closed['closed'], 1, reason: 'the foreman socket was open');
    final unreadBeforeDrop = unread(app);
    final p1 = (await app.read(
      workerAssignedProjectsProvider.future,
    )).firstWhere((p) => p.id == 'p1');
    final worker = app.read(sessionProvider).value!;
    await app
        .read(workerReportsApiProvider)
        .submitReport(
          projectId: p1.id,
          projectName: p1.name,
          phaseId: p1.phases.first.id,
          phaseName: p1.phases.first.name,
          employeeId: worker.employeeId,
          employeeName: worker.employeeName,
          description: 'Sent while the foreman was offline.',
          submittedAt: DateTime.now(),
          photos: const [],
          memoPath: null,
        );
    await pumpUntil(
      tester,
      () => unread(app) > unreadBeforeDrop,
      timeout: const Duration(seconds: 30),
      reason: 'notification after the socket came back',
    );

    // 10. Restart: both sessions are still there.

    step('10');
    await tester.pumpWidget(const SizedBox.shrink());
    app = await pumpApp(tester);
    await pumpUntil(
      tester,
      () =>
          app.read(authSessionProvider).value != null &&
          app.read(sessionProvider).value?.employeeId == 'e1',
      reason: 'sessions restored',
    );

    // 11. An expired access token refreshes on its own (the e2e server

    step('11');
    // issues 15-second foreman tokens).
    final tokenBefore = app.read(authSessionProvider).value!.token;
    await waitReal(tester, const Duration(seconds: 17));
    final clients = await within(app.read(clientsProvider.future));
    final c1 = clients.firstWhere((c) => c.id == 'c1');
    await app
        .read(clientsProvider.notifier)
        .updateClient(
          id: c1.id,
          name: c1.name,
          activeProjects: c1.activeProjects,
          type: c1.type,
          status: c1.status,
          preferredContactMethod: c1.preferredContactMethod,
          notes: 'Saved after a refresh.',
          email: c1.email,
          phone: c1.phone,
          addressLine1: c1.addressLine1,
          city: c1.city,
          stateProvince: c1.state,
          zipCode: c1.zipCode,
          contactPerson: c1.contactPerson,
        );
    expect(app.read(authSessionProvider).value!.token, isNot(tokenBefore));

    // 12. Deactivating the worker ends their session at the next call.

    step('12');
    final andrei = (await app.read(
      teamProvider.future,
    )).firstWhere((e) => e.id == 'e1');
    await app
        .read(teamProvider.notifier)
        .updateEmployee(
          id: andrei.id,
          name: andrei.name,
          role: andrei.role,
          email: andrei.email,
          phone: andrei.phone,
          workStartHour: andrei.workStartHour,
          workEndHour: andrei.workEndHour,
          workingDays: andrei.workingDays,
          isActive: false,
        );
    // The server caches who a token belongs to for a few seconds, so keep
    // making worker calls until one is refused with ACCOUNT_DISABLED.
    var lastCall = DateTime(0);
    await pumpUntil(tester, () {
      if (app.read(sessionProvider).value == null) return true;
      if (DateTime.now().difference(lastCall) > const Duration(seconds: 1)) {
        lastCall = DateTime.now();
        app.invalidate(workerAssignedProjectsProvider);
        app.read(workerAssignedProjectsProvider.future).ignore();
      }
      return false;
    }, reason: 'deactivated worker signed out');
    router().go('/worker/work');
    await settle(tester);
    expect(
      router().routerDelegate.currentConfiguration.uri.path,
      isNot('/worker/work'),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

int unread(ProviderContainer app) =>
    app.read(foremanNotificationsProvider).value?.unreadCount ?? 0;

/// Pumps frames until [done], or fails after [timeout]. The server is real,
/// so this waits in real time rather than on fake clocks.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
  String reason = '',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting: $reason');
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Waits for [finder], then for the page transition that brought it in to
/// finish: a widget is found while its route is still sliding in, and a tap
/// then would land on the page underneath.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  await pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    reason: '$finder',
  );
  await settle(tester);
  // A snack bar outlives the page that showed it and sits over the bottom
  // of the next one, where buttons like "Next" are.
  for (final messenger in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    messenger.clearSnackBars();
  }
  await tester.pump();
}

/// Lets animations and requests started by the last action finish.
Future<void> settle(WidgetTester tester) =>
    waitReal(tester, const Duration(milliseconds: 600));

Future<void> waitReal(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Marks progress in the log, so a hang shows which step it was in.
void step(String number) => debugPrint('e2e step $number');

/// A provider future that does not complete is a failure, not a hang.
Future<T> within<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 30));
