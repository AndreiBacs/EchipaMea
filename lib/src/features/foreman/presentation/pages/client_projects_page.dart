import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'project_form_page.dart';
import '../providers/clients_controller.dart';
import '../providers/projects_controller.dart';

class ClientProjectsPage extends ConsumerWidget {
  const ClientProjectsPage({super.key, required this.clientId});

  static const path = '/foreman/clients/:id/projects';

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final client = ref.read(clientsProvider.notifier).findById(clientId);
    final projects = ref
        .watch(projectsProvider)
        .where((project) => project.clientId == clientId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          client == null
              ? l10n.clientProjectsTitle
              : '${l10n.clientProjectsTitle}: ${client.name}',
        ),
      ),
      body: projects.isEmpty
          ? Center(child: Text(l10n.noProjectsForClient))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final project = projects[index];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.work_outline),
                    ),
                    title: Text(project.name),
                    subtitle: Text(
                      '${l10n.statusLabel}: ${_statusLabel(project.status, l10n)}\n'
                      '${project.workers.length} ${l10n.workerCountSuffix}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editProjectTooltip,
                      onPressed: () =>
                          context.push('/foreman/projects/${project.id}/edit'),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '${ProjectFormPage.createPath}?clientId=$clientId',
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProject),
      ),
    );
  }

  static String _statusLabel(ProjectStatus status, AppLocalizations l10n) {
    return switch (status) {
      ProjectStatus.planned => l10n.statusPlanned,
      ProjectStatus.inProgress => l10n.statusInProgress,
      ProjectStatus.done => l10n.statusDone,
    };
  }
}
