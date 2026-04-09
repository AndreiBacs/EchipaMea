import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../auth/auth_session_controller.dart';
import '../../features/foreman/presentation/pages/client_form_page.dart';
import '../../features/foreman/presentation/pages/employee_form_page.dart';
import '../../features/foreman/presentation/pages/foreman_shell_page.dart';
import '../../features/foreman/presentation/pages/project_form_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/legal/presentation/pages/terms_page.dart';
import '../../features/worker/presentation/pages/worker_connect_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: LoginPage.routePath,
    redirect: (context, state) {
      final isForemanRoute = state.matchedLocation.startsWith('/foreman');
      final isLoginRoute = state.matchedLocation == LoginPage.routePath;
      final session = authState is AsyncData<AuthSession?>
          ? authState.value
          : null;
      final isLoggedIn = session != null;

      if (authState.isLoading) return null;

      if (!isLoggedIn && isForemanRoute) {
        return LoginPage.routePath;
      }

      if (isLoggedIn && isLoginRoute) {
        return ForemanShellPage.dashboardPath;
      }

      return null;
    },
    routes: [
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
        builder: (context, state) =>
            const ForemanShellPage(currentTab: ForemanTab.dashboard),
      ),
      GoRoute(
        path: ForemanShellPage.projectsPath,
        name: 'foreman_projects',
        builder: (context, state) =>
            const ForemanShellPage(currentTab: ForemanTab.projects),
      ),
      GoRoute(
        path: ForemanShellPage.teamPath,
        name: 'foreman_team',
        builder: (context, state) =>
            const ForemanShellPage(currentTab: ForemanTab.team),
      ),
      GoRoute(
        path: ForemanShellPage.clientsPath,
        name: 'foreman_clients',
        builder: (context, state) =>
            const ForemanShellPage(currentTab: ForemanTab.clients),
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
        path: ProjectFormPage.createPath,
        name: 'project_create',
        builder: (context, state) => const ProjectFormPage(),
      ),
      GoRoute(
        path: ProjectFormPage.editPath,
        name: 'project_edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProjectFormPage(projectId: id);
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
        path: WorkerConnectPage.routePath,
        name: WorkerConnectPage.routeName,
        builder: (context, state) => const WorkerConnectPage(),
      ),
      GoRoute(
        path: TermsPage.routePath,
        name: TermsPage.routeName,
        builder: (context, state) => const TermsPage(),
      ),
    ],
  );
});
