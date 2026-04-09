import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.projectFormEditTitle : l10n.projectFormAddTitle,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = AdaptiveBreakpoints.sizeClassForWidth(
            constraints.maxWidth,
          );
          final formWidth = switch (sizeClass) {
            AdaptiveSizeClass.compact => constraints.maxWidth,
            AdaptiveSizeClass.medium => 640.0,
            AdaptiveSizeClass.expanded => 720.0,
          };
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: formWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.projectNameLabel),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ProjectStatus>(
                      initialValue: _selectedStatus,
                      items: ProjectStatus.values
                          .map(
                            (status) => DropdownMenuItem<ProjectStatus>(
                              value: status,
                              child: Text(_statusLabel(context, status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedStatus = value);
                      },
                      decoration: InputDecoration(labelText: l10n.statusLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _workersController,
                      decoration: InputDecoration(
                        labelText: l10n.workersCommaSeparatedLabel,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                context.go(ForemanShellPage.projectsPath),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _save(context, isEdit: isEdit),
                            child: Text(
                              isEdit ? l10n.saveChanges : l10n.createProject,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

  String _statusLabel(BuildContext context, ProjectStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      ProjectStatus.planned => l10n.statusPlanned,
      ProjectStatus.inProgress => l10n.statusInProgress,
      ProjectStatus.done => l10n.statusDone,
    };
  }
}
