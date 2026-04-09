import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../providers/worker_assigned_projects_provider.dart';
import '../../application/worker_foreman_inbox_controller.dart';
import 'worker_report_flow_page.dart';

class WorkerProjectDetailPage extends ConsumerWidget {
  const WorkerProjectDetailPage({super.key, required this.projectId});

  static String pathFor(String projectId) => '/worker/project/$projectId';

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final project = ref.watch(projectsProvider.select((list) {
      for (final p in list) {
        if (p.id == projectId) return p;
      }
      return null;
    }));
    final assigned = ref.watch(workerAssignedProjectsProvider);
    final isAssigned =
        project != null && assigned.any((p) => p.id == project.id);

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (project == null || !isAssigned) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workerProjectDetails)),
        body: Center(child: Text(l10n.workerProjectNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.workerProjectDetails)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            project.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.statusLabel}: ${_statusLabel(l10n, project.status)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.workerAssignedWorkersLabel}: ${project.workersLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (project.latitude != null && project.longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.workerCoordinatesHint}: '
              '${project.latitude!.toStringAsFixed(5)}, '
              '${project.longitude!.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: project.latitude != null && project.longitude != null
                ? () => _openMaps(
                      context,
                      l10n,
                      project.latitude!,
                      project.longitude!,
                    )
                : null,
            icon: const Icon(Icons.navigation),
            label: Text(l10n.workerOpenNavigation),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              ref.read(workerForemanInboxProvider.notifier).announceArrival(
                    projectId: project.id,
                    projectName: project.name,
                    employeeId: session.employeeId,
                    employeeName: session.employeeName,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.workerArrivalSent)),
              );
            },
            icon: const Icon(Icons.place),
            label: Text(l10n.workerAnnounceArrival),
          ),
          if (project.latitude == null || project.longitude == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.workerLocationMissing,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          const SizedBox(height: 32),
          if (project.status != ProjectStatus.done)
            FilledButton.icon(
              onPressed: () => context.push(
                WorkerReportFlowPage.pathFor(project.id),
              ),
              icon: const Icon(Icons.task_alt),
              label: Text(l10n.workerCompleteWork),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(AppLocalizations l10n, ProjectStatus status) {
    return switch (status) {
      ProjectStatus.planned => l10n.statusPlanned,
      ProjectStatus.inProgress => l10n.statusInProgress,
      ProjectStatus.done => l10n.statusDone,
    };
  }

  static Future<void> _openMaps(
    BuildContext context,
    AppLocalizations l10n,
    double lat,
    double lng,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await canLaunchUrl(uri)) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.workerNavigationOpenFailed)),
        );
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.workerNavigationOpenFailed)),
        );
      }
    } catch (error) {
      debugPrint('Failed to open navigation URL: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.workerNavigationOpenFailed)),
      );
    }
  }
}
