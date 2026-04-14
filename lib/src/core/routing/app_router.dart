import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/onboarding/presentation/pages/setup_flow_page.dart';
import '../auth/auth_session_controller.dart';
import '../auth/session_controller.dart';
import '../setup/setup_flow_controller.dart';
import '../../features/foreman/presentation/pages/client_form_page.dart';
import '../../features/foreman/presentation/pages/client_projects_page.dart';
import '../../features/foreman/presentation/pages/employee_form_page.dart';
import '../../features/foreman/presentation/pages/foreman_shell_page.dart';
import '../../features/foreman/presentation/pages/foreman_getting_started_page.dart';
import '../../features/foreman/presentation/pages/project_form_page.dart';
import '../../features/foreman/presentation/pages/project_phase_form_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/legal/presentation/pages/terms_page.dart';
import '../../features/worker/presentation/pages/worker_connect_page.dart';
import '../../features/worker/presentation/pages/worker_project_detail_page.dart';
import '../../features/worker/presentation/pages/worker_report_flow_page.dart';
import '../../features/worker/presentation/pages/worker_shell_page.dart';

NoTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authSessionProvider);
  final setupState = ref.watch(setupFlowCompletedProvider);
  ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: LoginPage.routePath,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final setupComplete = setupState is AsyncData<bool>
          ? setupState.value
          : null;
      final isSetupRoute = loc == SetupFlowPage.routePath;
      final isTermsRoute = loc == TermsPage.routePath;

      if (setupState.isLoading) return null;

      if (setupComplete == false) {
        if (isTermsRoute) return null;
        if (!isSetupRoute) return SetupFlowPage.routePath;
        return null;
      }

      if (setupComplete == true && isSetupRoute) {
        return LoginPage.routePath;
      }

      final isForemanRoute = loc.startsWith('/foreman');
      final isWorkerAppRoute = loc.startsWith('/worker');
      final isWorkerConnectRoute = loc == WorkerConnectPage.routePath;
      final isLoginRoute = loc == LoginPage.routePath;
      final foremanSession = authState is AsyncData<AuthSession?>
          ? authState.value
          : null;
      final isForemanLoggedIn = foremanSession != null;
      final workerSession = ref.read(sessionProvider);

      if (authState.isLoading) return null;

      if (!isForemanLoggedIn && isForemanRoute) {
        return LoginPage.routePath;
      }

      if (isWorkerAppRoute && !isWorkerConnectRoute && workerSession == null) {
        return LoginPage.routePath;
      }

      if (isWorkerConnectRoute && workerSession != null) {
        return WorkerShellPage.workPath;
      }

      // Allow worker shell when a worker session exists, even if foreman token
      // is still stored (e.g. same device tested both roles).
      if (isForemanLoggedIn &&
          isWorkerAppRoute &&
          !isWorkerConnectRoute &&
          workerSession == null) {
        return ForemanShellPage.dashboardPath;
      }

      if (!isForemanLoggedIn && workerSession != null && isLoginRoute) {
        return WorkerShellPage.workPath;
      }

      if (isForemanLoggedIn && isLoginRoute) {
        return ForemanShellPage.dashboardPath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SetupFlowPage.routePath,
        name: SetupFlowPage.routeName,
        builder: (context, state) => const SetupFlowPage(),
      ),
      GoRoute(
        path: LoginPage.routePath,
        name: LoginPage.routeName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: HomePage.routePath,
        name: HomePage.routeName,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: ForemanShellPage.dashboardPath,
        name: 'foreman_dashboard',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const ForemanShellPage(currentTab: ForemanTab.dashboard),
        ),
      ),
      GoRoute(
        path: ForemanShellPage.projectsPath,
        name: 'foreman_projects',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const ForemanShellPage(currentTab: ForemanTab.projects),
        ),
      ),
      GoRoute(
        path: ForemanShellPage.clientsPath,
        name: 'foreman_clients',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const ForemanShellPage(currentTab: ForemanTab.clients),
        ),
      ),
      GoRoute(
        path: ForemanShellPage.teamPath,
        name: 'foreman_team',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const ForemanShellPage(currentTab: ForemanTab.team),
        ),
      ),
      GoRoute(
        path: ForemanShellPage.profilePath,
        name: 'foreman_profile',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const ForemanShellPage(currentTab: ForemanTab.profile),
        ),
      ),
      GoRoute(
        path: ForemanGettingStartedPage.path,
        name: 'foreman_getting_started',
        builder: (context, state) => const ForemanGettingStartedPage(),
      ),
      GoRoute(
        path: ClientFormPage.createPath,
        name: 'client_create',
        builder: (context, state) => const ClientFormPage(),
      ),
      GoRoute(
        path: ClientFormPage.editPath,
        name: 'client_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientFormPage(clientId: id);
        },
      ),
      GoRoute(
        path: ClientProjectsPage.path,
        name: 'client_projects',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientProjectsPage(clientId: id);
        },
      ),
      GoRoute(
        path: ProjectFormPage.createPath,
        name: 'project_create',
        builder: (context, state) {
          final initialClientId = state.uri.queryParameters['clientId'];
          return ProjectFormPage(initialClientId: initialClientId);
        },
      ),
      GoRoute(
        path: ProjectFormPage.editPath,
        name: 'project_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final tab = state.uri.queryParameters['tab'];
          final initialTabIndex = tab == 'phases' ? 1 : 0;
          return ProjectFormPage(
            projectId: id,
            initialTabIndex: initialTabIndex,
          );
        },
      ),
      GoRoute(
        path: ProjectPhaseFormPage.newPath,
        name: 'project_phase_new',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return ProjectPhaseFormPage(projectId: projectId);
        },
      ),
      GoRoute(
        path: ProjectPhaseFormPage.editPath,
        name: 'project_phase_edit',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          final phaseId = state.pathParameters['phaseId']!;
          return ProjectPhaseFormPage(projectId: projectId, phaseId: phaseId);
        },
      ),
      GoRoute(
        path: EmployeeFormPage.createPath,
        name: 'employee_create',
        builder: (context, state) => const EmployeeFormPage(),
      ),
      GoRoute(
        path: EmployeeFormPage.editPath,
        name: 'employee_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EmployeeFormPage(employeeId: id);
        },
      ),
      GoRoute(
        path: WorkerShellPage.workPath,
        name: 'worker_work',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const WorkerShellPage(currentTab: WorkerTab.work),
        ),
      ),
      GoRoute(
        path: WorkerShellPage.profilePath,
        name: 'worker_profile',
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: const WorkerShellPage(currentTab: WorkerTab.profile),
        ),
      ),
      GoRoute(
        path: WorkerConnectPage.routePath,
        name: WorkerConnectPage.routeName,
        builder: (context, state) => const WorkerConnectPage(),
      ),
      GoRoute(
        path: '/worker/project/:projectId',
        name: 'worker_project_detail',
        builder: (context, state) {
          final id = state.pathParameters['projectId']!;
          return WorkerProjectDetailPage(projectId: id);
        },
        routes: [
          GoRoute(
            path: 'report',
            name: 'worker_project_report',
            builder: (context, state) {
              final id = state.pathParameters['projectId']!;
              return WorkerReportFlowPage(projectId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: TermsPage.routePath,
        name: TermsPage.routeName,
        builder: (context, state) => const TermsPage(),
      ),
    ],
  );
});
