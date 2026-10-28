import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import '../../../../core/ui/async_status_view.dart';
import '../providers/projects_controller.dart';
import '../providers/team_controller.dart';
import '../widgets/phase_work_instructions_editor.dart';

/// Full-screen form to add or edit a [ProjectPhase] (name, description, team).
class ProjectPhaseFormPage extends ConsumerWidget {
  const ProjectPhaseFormPage({
    super.key,
    required this.projectId,
    this.phaseId,
  });

  static const newPath = '/foreman/projects/:projectId/phases/new';
  static const editPath = '/foreman/projects/:projectId/phases/:phaseId/edit';

  static String pathNew(String projectId) =>
      '/foreman/projects/$projectId/phases/new';

  static String pathEdit(String projectId, String phaseId) =>
      '/foreman/projects/$projectId/phases/$phaseId/edit';

  final String projectId;
  final String? phaseId;

  bool get isNew => phaseId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolved before the form is built, because the form copies the phase
    // into its fields once, in initState.
    final l10n = context.l10n;
    final projectsState = ref.watch(projectsProvider);
    final projects = projectsState.current;
    final project = projects?.where((p) => p.id == projectId).firstOrNull;
    final phase = project?.phases.where((p) => p.id == phaseId).firstOrNull;
    if (project != null && (isNew || phase != null)) {
      return _PhaseForm(
        key: ValueKey('$projectId/$phaseId'),
        projectId: projectId,
        existing: phase,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? l10n.addPhase : l10n.editPhase)),
      body: projects == null
          ? AsyncStatusView(
              projectsState,
              onRetry: () => ref.invalidate(projectsProvider),
            )
          : Center(child: Text(l10n.workerProjectNotFound)),
    );
  }
}

class _PhaseForm extends ConsumerStatefulWidget {
  const _PhaseForm({
    super.key,
    required this.projectId,
    required this.existing,
  });

  final String projectId;

  /// Null when adding a phase.
  final ProjectPhase? existing;

  bool get isNew => existing == null;

  @override
  ConsumerState<_PhaseForm> createState() => _PhaseFormState();
}

class _PhaseFormState extends ConsumerState<_PhaseForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  var _selectedEmployeeIds = <String>{};
  late PhaseWorkInstructionsSnapshot _instructionsSnap;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final phase = widget.existing;
    _nameController = TextEditingController(text: phase?.name ?? '');
    _descriptionController = TextEditingController(
      text: phase?.description ?? '',
    );
    final today = DateTime.now();
    _startDate =
        phase?.startDate ?? DateTime(today.year, today.month, today.day);
    _endDate = phase?.endDate ?? DateTime(today.year, today.month, today.day);
    _selectedEmployeeIds = {if (phase != null) ...phase.assignedEmployeeIds};
    _instructionsSnap = PhaseWorkInstructionsSnapshot(
      items: [
        for (final w
            in phase?.workInstructions ?? const <PhaseWorkInstruction>[])
          w.copyWith(
            photoPaths: List<String>.from(w.photoPaths),
            audioPaths: List<String>.from(w.audioPaths),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = ref.watch(teamProvider).current ?? const <Employee>[];
    final phase = widget.existing;
    final isDone = phase?.status == PhaseStatus.done;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l10n.addPhase : l10n.editPhase),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isDone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.phaseEditDoneHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  TextField(
                    controller: _nameController,
                    readOnly: isDone,
                    decoration: InputDecoration(labelText: l10n.phaseNameLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.phaseDescriptionLabel,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DateRangeFields(
                    startDate: _startDate,
                    endDate: _endDate,
                    readOnly: isDone,
                    onPickStart: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _startDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                        if (_endDate.isBefore(_startDate)) {
                          _endDate = _startDate;
                        }
                      });
                    },
                    onPickEnd: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate.isBefore(_startDate)
                            ? _startDate
                            : _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _endDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  PhaseWorkInstructionsEditor(
                    key: ValueKey(
                      'phase_instr_${widget.existing?.id ?? widget.projectId}',
                    ),
                    l10n: l10n,
                    readOnly: isDone,
                    initialItems: _instructionsSnap.items,
                    onChanged: (s) => setState(() => _instructionsSnap = s),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.assignEmployees,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.phaseAssignedCount}: ${_selectedEmployeeIds.length} / ${team.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...team.map(
                    (employee) => CheckboxListTile(
                      value: _selectedEmployeeIds.contains(employee.id),
                      title: Text(employee.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: isDone
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedEmployeeIds.add(employee.id);
                                } else {
                                  _selectedEmployeeIds.remove(employee.id);
                                }
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(l10n.saveChanges),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_endDate.isBefore(_startDate)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.phaseDateValidationEndAfterStart)),
      );
      return;
    }
    final description = _descriptionController.text.trim();
    final ids = _selectedEmployeeIds.toList();
    final existing = widget.existing;
    final notifier = ref.read(projectsProvider.notifier);
    final router = GoRouter.of(context);

    setState(() => _saving = true);
    try {
      if (existing == null) {
        await notifier.addPhase(
          projectId: widget.projectId,
          name: name,
          startDate: _startDate,
          endDate: _endDate,
          assignedEmployeeIds: ids,
          description: description,
          workInstructions: _instructionsSnap.forPersistence(),
        );
      } else {
        await notifier.updatePhase(
          projectId: widget.projectId,
          phaseId: existing.id,
          name: name,
          startDate: _startDate,
          endDate: _endDate,
          assignedEmployeeIds: ids,
          description: description,
          workInstructions: _instructionsSnap.forPersistence(),
        );
      }
      router.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateRangeFields extends StatelessWidget {
  const _DateRangeFields({
    required this.startDate,
    required this.endDate,
    required this.readOnly,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime startDate;
  final DateTime endDate;
  final bool readOnly;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: readOnly ? null : onPickStart,
            icon: const Icon(Icons.event),
            label: Text(
              l10n.plannerFromDate(localizations.formatMediumDate(startDate)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: readOnly ? null : onPickEnd,
            icon: const Icon(Icons.event_available),
            label: Text(
              l10n.plannerToDate(localizations.formatMediumDate(endDate)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
