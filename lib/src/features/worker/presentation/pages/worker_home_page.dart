import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../providers/worker_assigned_projects_provider.dart';
import 'worker_project_detail_page.dart';

class WorkerHomePage extends ConsumerWidget {
  const WorkerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assigned = ref.watch(workerAssignedProjectsProvider);

    if (assigned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.workerNoAssignments,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final next = assigned.first;
    final rest = assigned.length > 1 ? assigned.sublist(1) : const <Project>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workerNextUp,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _NextWorkCard(
          project: next,
          onTap: () => context.push(
            WorkerProjectDetailPage.pathFor(next.id),
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.workerUpcomingWork,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...rest.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p.name),
                subtitle: Text(_statusLabel(l10n, p.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  WorkerProjectDetailPage.pathFor(p.id),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _statusLabel(AppLocalizations l10n, ProjectStatus status) {
    return switch (status) {
      ProjectStatus.planned => l10n.statusPlanned,
      ProjectStatus.inProgress => l10n.statusInProgress,
      ProjectStatus.done => l10n.statusDone,
    };
  }
}

class _NextWorkCard extends StatelessWidget {
  const _NextWorkCard({
    required this.project,
    required this.onTap,
  });

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                WorkerHomePage._statusLabel(l10n, project.status),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.workerViewDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
