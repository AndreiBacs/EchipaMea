import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'foreman_shell_page.dart';
import '../providers/projects_controller.dart';

class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({super.key, this.projectId});

  static const createPath = '/foreman/projects/new';
  static const editPath = '/foreman/projects/:id/edit';

  final String? projectId;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _workersController;
  late ProjectStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    final existing = widget.projectId == null
        ? null
        : ref.read(projectsProvider.notifier).findById(widget.projectId!);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _workersController = TextEditingController(
      text: existing?.workers.join(', ') ?? '',
    );
    _selectedStatus = existing?.status ?? ProjectStatus.planned;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.projectId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit project' : 'Add project')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectStatus>(
              initialValue: _selectedStatus,
              items: ProjectStatus.values
                  .map(
                    (status) => DropdownMenuItem<ProjectStatus>(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStatus = value);
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workersController,
              decoration: const InputDecoration(
                labelText: 'Workers (comma separated)',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go(ForemanShellPage.projectsPath),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(context, isEdit: isEdit),
                    child: Text(isEdit ? 'Save changes' : 'Create project'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save(BuildContext context, {required bool isEdit}) {
    final name = _nameController.text.trim();
    final workers = _workersController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (name.isEmpty) return;

    if (isEdit) {
      ref
          .read(projectsProvider.notifier)
          .updateProject(
            id: widget.projectId!,
            name: name,
            status: _selectedStatus,
            workers: workers,
          );
    } else {
      ref
          .read(projectsProvider.notifier)
          .addProject(name: name, status: _selectedStatus, workers: workers);
    }

    Navigator.of(context).pop();
  }
}
