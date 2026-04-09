import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'project_form_page.dart';
import '../providers/projects_controller.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Projects (${projects.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(ProjectFormPage.createPath),
                icon: const Icon(Icons.add),
                label: const Text('Add project'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                leading: const Icon(Icons.business),
                title: Text(project.name),
                subtitle: Text(
                  'Status: ${project.status.label}\nWorkers: ${project.workersLabel}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit project',
                  onPressed: () =>
                      context.push('/foreman/projects/${project.id}/edit'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
