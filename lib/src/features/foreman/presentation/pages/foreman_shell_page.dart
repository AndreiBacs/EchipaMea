import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/adaptive_breakpoints.dart';
import 'clients_page.dart';
import 'dashboard_page.dart';
import 'projects_page.dart';
import 'team_page.dart';

enum ForemanTab { dashboard, projects, team, clients }

class ForemanShellPage extends StatelessWidget {
  const ForemanShellPage({super.key, required this.currentTab});

  static const dashboardPath = '/foreman/dashboard';
  static const projectsPath = '/foreman/projects';
  static const teamPath = '/foreman/team';
  static const clientsPath = '/foreman/clients';

  final ForemanTab currentTab;

  @override
  Widget build(BuildContext context) {
    final body = switch (currentTab) {
      ForemanTab.dashboard => const DashboardPage(),
      ForemanTab.projects => const ProjectsPage(),
      ForemanTab.team => const TeamPage(),
      ForemanTab.clients => const ClientsPage(),
    };
    final sizeClass = AdaptiveBreakpoints.fromContext(context);
    final useBottomNav = sizeClass == AdaptiveSizeClass.compact;
    final useRail = sizeClass == AdaptiveSizeClass.medium;

    return Scaffold(
      appBar: AppBar(title: const Text('Foreman')),
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
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.work),
                        label: Text('Projects'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.groups),
                        label: Text('Team'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.handshake),
                        label: Text('Clients'),
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
                      children: const [
                        Padding(
                          padding: EdgeInsets.fromLTRB(28, 16, 16, 8),
                          child: Text(
                            'Navigation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NavigationDrawerDestination(
                          icon: Icon(Icons.dashboard),
                          label: Text('Dashboard'),
                        ),
                        NavigationDrawerDestination(
                          icon: Icon(Icons.work),
                          label: Text('Projects'),
                        ),
                        NavigationDrawerDestination(
                          icon: Icon(Icons.groups),
                          label: Text('Team'),
                        ),
                        NavigationDrawerDestination(
                          icon: Icon(Icons.handshake),
                          label: Text('Clients'),
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
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.work),
                  label: 'Projects',
                ),
                NavigationDestination(icon: Icon(Icons.groups), label: 'Team'),
                NavigationDestination(
                  icon: Icon(Icons.handshake),
                  label: 'Clients',
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
      ForemanTab.projects => projectsPath,
      ForemanTab.team => teamPath,
      ForemanTab.clients => clientsPath,
    };
    context.go(path);
  }
}
