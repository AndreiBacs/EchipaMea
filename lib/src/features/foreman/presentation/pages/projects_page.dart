import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'project_form_page.dart';
import '../providers/projects_controller.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    final l10n = context.l10n;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: isTablet ? 400 : MediaQuery.sizeOf(context).width - 64,
                child: Text(
                  '${l10n.projectsTitle} (${projects.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 8,
                  8,
                  isTablet ? 24 : 8,
                  96,
                ),
                itemCount: projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return Dismissible(
                    key: ValueKey('project_${project.id}'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      context.push('/foreman/projects/${project.id}/edit');
                      return false;
                    },
                    background: _SwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      icon: Icons.edit_outlined,
                      label: l10n.quickEdit,
                    ),
                    secondaryBackground: _SwipeActionBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.edit_outlined,
                      label: l10n.quickEdit,
                    ),
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.business_center_outlined),
                        ),
                        title: Text(
                          project.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _StatusChip(status: project.status),
                                  Text(
                                    '${project.workers.length} ${l10n.workerCountSuffix}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                project.workersLabel,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l10n.editProjectTooltip,
                          onPressed: () =>
                              context.push('/foreman/projects/${project.id}/edit'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => context.push(ProjectFormPage.createPath),
            icon: const Icon(Icons.add),
            label: Text(l10n.addProject),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (bg, fg, icon) = switch (status) {
      ProjectStatus.planned => (
        Colors.blue.withValues(alpha: 0.12),
        Colors.blue.shade800,
        Icons.schedule_outlined,
      ),
      ProjectStatus.inProgress => (
        Colors.orange.withValues(alpha: 0.14),
        Colors.orange.shade900,
        Icons.construction_outlined,
      ),
      ProjectStatus.done => (
        Colors.green.withValues(alpha: 0.14),
        Colors.green.shade900,
        Icons.check_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            switch (status) {
              ProjectStatus.planned => l10n.statusPlanned,
              ProjectStatus.inProgress => l10n.statusInProgress,
              ProjectStatus.done => l10n.statusDone,
            },
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
