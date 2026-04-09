import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Foreman')),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (index) => _onTabSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.work), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Team'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'Clients'),
        ],
      ),
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
