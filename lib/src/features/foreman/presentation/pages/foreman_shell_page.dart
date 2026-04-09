import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import 'clients_page.dart';
import 'dashboard_page.dart';
import 'foreman_map_page.dart';
import 'projects_page.dart';
import 'team_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

enum ForemanTab { dashboard, map, projects, team, clients, profile }

class ForemanShellPage extends ConsumerWidget {
  const ForemanShellPage({super.key, required this.currentTab});

  static const dashboardPath = '/foreman/dashboard';
  static const mapPath = '/foreman/map';
  static const projectsPath = '/foreman/projects';
  static const teamPath = '/foreman/team';
  static const clientsPath = '/foreman/clients';
  static const profilePath = '/foreman/profile';

  final ForemanTab currentTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final body = switch (currentTab) {
      ForemanTab.dashboard => const DashboardPage(),
      ForemanTab.map => const ForemanMapPage(),
      ForemanTab.projects => const ProjectsPage(),
      ForemanTab.team => const TeamPage(),
      ForemanTab.clients => const ClientsPage(),
      ForemanTab.profile => const ProfilePage(),
    };
    final sizeClass = AdaptiveBreakpoints.fromContext(context);
    final useBottomNav = sizeClass == AdaptiveSizeClass.compact;
    final useRail = sizeClass == AdaptiveSizeClass.medium;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.foremanShellTitle),
        actions: [
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: useBottomNav
          ? body
          : Row(
              children: [
                if (useRail)
                  NavigationRail(
                    selectedIndex: currentTab.index,
                    onDestinationSelected: (index) =>
                        _onTabSelected(context, index),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.dashboard),
                        label: Text(l10n.dashboardTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l10n.mapTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.work),
                        label: Text(l10n.projectsTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.groups),
                        label: Text(l10n.teamTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.handshake),
                        label: Text(l10n.clientsTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person),
                        label: Text(l10n.profileTab),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: 280,
                    child: NavigationDrawer(
                      selectedIndex: currentTab.index,
                      onDestinationSelected: (index) =>
                          _onTabSelected(context, index),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
                          child: Text(
                            l10n.navigation,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.dashboard),
                          label: Text(l10n.dashboardTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.map_outlined),
                          label: Text(l10n.mapTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.work),
                          label: Text(l10n.projectsTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.groups),
                          label: Text(l10n.teamTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.handshake),
                          label: Text(l10n.clientsTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.person),
                          label: Text(l10n.profileTab),
                        ),
                      ],
                    ),
                  ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
      bottomNavigationBar: useBottomNav
          ? NavigationBar(
              selectedIndex: currentTab.index,
              onDestinationSelected: (index) => _onTabSelected(context, index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard),
                  label: l10n.dashboardTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  label: l10n.mapTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.work),
                  label: l10n.projectsTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups),
                  label: l10n.teamTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.handshake),
                  label: l10n.clientsTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: l10n.profileTab,
                ),
              ],
            )
          : null,
    );
  }

  void _onTabSelected(BuildContext context, int index) {
    final tab = ForemanTab.values[index];
    final path = switch (tab) {
      ForemanTab.dashboard => dashboardPath,
      ForemanTab.map => mapPath,
      ForemanTab.projects => projectsPath,
      ForemanTab.team => teamPath,
      ForemanTab.clients => clientsPath,
      ForemanTab.profile => profilePath,
    };
    context.go(path);
  }
}
