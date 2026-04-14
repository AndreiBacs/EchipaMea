import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import 'foreman_shell_page.dart';
import 'project_phase_form_page.dart';
import '../providers/clients_controller.dart';
import '../providers/projects_controller.dart';
import '../providers/team_controller.dart';
import '../widgets/phase_work_instructions_editor.dart';

class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({
    super.key,
    this.projectId,
    this.initialClientId,
    this.initialTabIndex = 0,
  });

  static const createPath = '/foreman/projects/new';
  static const editPath = '/foreman/projects/:id/edit';

  /// Opens edit route with the Phases tab selected.
  static String editPathWithPhasesTab(String projectId) =>
      '/foreman/projects/$projectId/edit?tab=phases';

  final String? projectId;
  final String? initialClientId;

  /// `0` = details, `1` = phases.
  final int initialTabIndex;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipCodeController;
  late ProjectStatus _selectedStatus;
  bool _useClientAddress = true;
  String? _selectedClientId;

  /// Draft phases while creating a project (saved with [addProject]).
  List<ProjectPhase> _draftPhases = [];
  late DateTime _selectedPlanningDay;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final existing = widget.projectId == null
        ? null
        : ref.read(projectsProvider.notifier).findById(widget.projectId!);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressLine1Controller = TextEditingController(
      text: existing?.addressLine1 ?? '',
    );
    _cityController = TextEditingController(text: existing?.city ?? '');
    _stateController = TextEditingController(text: existing?.state ?? '');
    _zipCodeController = TextEditingController(text: existing?.zipCode ?? '');
    _selectedStatus = existing?.status ?? ProjectStatus.planned;
    _selectedClientId = existing?.clientId ?? widget.initialClientId;
    _useClientAddress = existing?.useClientAddress ?? true;
    final today = DateTime.now();
    _selectedPlanningDay = DateTime(today.year, today.month, today.day);
    if (_useClientAddress) {
      _syncAddressFromClient();
    }

    final tabIndex = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: tabIndex,
    );
    _tabController.addListener(_onTabControllerTick);
  }

  void _onTabControllerTick() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  void _onAddPhaseFabPressed() {
    final l10n = context.l10n;
    final team = ref.read(teamProvider);
    final projectId = widget.projectId;
    if (projectId != null) {
      context.push(ProjectPhaseFormPage.pathNew(projectId));
    } else {
      _showDraftPhaseDialog(context, l10n, team, existing: null);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerTick);
    _tabController.dispose();
    _nameController.dispose();
    _addressLine1Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.projectId != null;
    final lockClientSelection = !isEdit && widget.initialClientId != null;
    final l10n = context.l10n;
    final clients = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.projectFormEditTitle : l10n.projectFormAddTitle,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.projectFormDetailsTab),
            Tab(text: l10n.phasesLabel),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _onAddPhaseFabPressed,
              icon: const Icon(Icons.add),
              label: Text(l10n.addPhase),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(context, l10n, clients, isEdit, lockClientSelection),
          _buildPhasesTab(context, l10n, isEdit),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(
    BuildContext context,
    AppLocalizations l10n,
    List<Client> clients,
    bool isEdit,
    bool lockClientSelection,
  ) {
    // Normalize: if the stored clientId is no longer in the list, treat as unselected.
    final validClientId = clients.any((c) => c.id == _selectedClientId)
        ? _selectedClientId
        : null;

    return LayoutBuilder(
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
                    decoration: InputDecoration(
                      labelText: l10n.projectNameLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: validClientId,
                    items: clients
                        .map(
                          (client) => DropdownMenuItem<String>(
                            value: client.id,
                            child: Text(client.name),
                          ),
                        )
                        .toList(),
                    onChanged: lockClientSelection
                        ? null
                        : (value) {
                            setState(() => _selectedClientId = value);
                            if (_useClientAddress) {
                              _syncAddressFromClient();
                            }
                          },
                    decoration: InputDecoration(labelText: l10n.clientLabel),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.useClientAddress),
                    value: _useClientAddress,
                    onChanged: (value) {
                      setState(() => _useClientAddress = value);
                      if (value) {
                        _syncAddressFromClient();
                      }
                    },
                  ),
                  TextField(
                    controller: _addressLine1Controller,
                    enabled: !_useClientAddress,
                    decoration: InputDecoration(
                      labelText: l10n.projectAddressLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityController,
                    enabled: !_useClientAddress,
                    decoration: InputDecoration(labelText: l10n.cityLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stateController,
                    enabled: !_useClientAddress,
                    decoration: InputDecoration(labelText: l10n.countyLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _zipCodeController,
                    enabled: !_useClientAddress,
                    decoration: InputDecoration(labelText: l10n.zipCodeLabel),
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
    );
  }

  Widget _buildPhasesTab(
    BuildContext context,
    AppLocalizations l10n,
    bool isEdit,
  ) {
    final team = ref.watch(teamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = AdaptiveBreakpoints.sizeClassForWidth(
          constraints.maxWidth,
        );
        final formWidth = switch (sizeClass) {
          AdaptiveSizeClass.compact => constraints.maxWidth,
          AdaptiveSizeClass.medium => 640.0,
          AdaptiveSizeClass.expanded => 720.0,
        };

        if (!isEdit) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: formWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _DraftPhasesList(
                    phases: _draftPhases,
                    l10n: l10n,
                    onEdit: (phase) => _showDraftPhaseDialog(
                      context,
                      l10n,
                      team,
                      existing: phase,
                    ),
                    onRemove: (phaseId) {
                      setState(() {
                        _draftPhases = [
                          for (final p in _draftPhases)
                            if (p.id != phaseId) p,
                        ];
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _MembersByPhaseCard(
                    phases: _draftPhases,
                    employeesById: {
                      for (final employee in team) employee.id: employee.name,
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final projectId = widget.projectId!;
        final projects = ref.watch(projectsProvider);
        Project? project;
        for (final p in projects) {
          if (p.id == projectId) {
            project = p;
            break;
          }
        }

        if (project == null) {
          return Center(child: Text(l10n.workerProjectNotFound));
        }
        final resolvedProject = project;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: formWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _ProjectPhasesList(
                  project: resolvedProject,
                  l10n: l10n,
                  onEdit: (phase) => context.push(
                    ProjectPhaseFormPage.pathEdit(resolvedProject.id, phase.id),
                  ),
                  onRemove: (phase) {
                    if (phase.status != PhaseStatus.notStarted) return;
                    ref
                        .read(projectsProvider.notifier)
                        .removePhase(
                          projectId: resolvedProject.id,
                          phaseId: phase.id,
                        );
                  },
                  onApprove: (phase) {
                    ref
                        .read(projectsProvider.notifier)
                        .reviewPhase(
                          projectId: resolvedProject.id,
                          phaseId: phase.id,
                          approved: true,
                          foremanId: 'foreman_local',
                        );
                  },
                  onReject: (phase) {
                    ref
                        .read(projectsProvider.notifier)
                        .reviewPhase(
                          projectId: resolvedProject.id,
                          phaseId: phase.id,
                          approved: false,
                          foremanId: 'foreman_local',
                        );
                  },
                ),
                const SizedBox(height: 12),
                _MembersByPhaseCard(
                  phases: resolvedProject.phases,
                  employeesById: {
                    for (final employee in team) employee.id: employee.name,
                  },
                ),
                const SizedBox(height: 12),
                _DailySequencePlannerCard(
                  selectedDay: _selectedPlanningDay,
                  onPickDay: (pickedDay) {
                    setState(() => _selectedPlanningDay = pickedDay);
                  },
                  project: resolvedProject,
                  team: team,
                  notifier: ref.read(projectsProvider.notifier),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Quick add/edit for draft phases only (project not saved yet).
  Future<void> _showDraftPhaseDialog(
    BuildContext context,
    AppLocalizations l10n,
    List<Employee> team, {
    required ProjectPhase? existing,
  }) async {
    final isEditMode = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final selectedEmployeeIds = <String>{
      if (existing != null) ...existing.assignedEmployeeIds,
    };
    final today = DateTime.now();
    var startDate =
        existing?.startDate ?? DateTime(today.year, today.month, today.day);
    var endDate =
        existing?.endDate ?? DateTime(today.year, today.month, today.day);

    var draftInstructions = PhaseWorkInstructionsSnapshot(
      items: [
        for (final w
            in existing?.workInstructions ?? const <PhaseWorkInstruction>[])
          PhaseWorkInstruction(
            id: w.id,
            text: w.text,
            photoPaths: List<String>.from(w.photoPaths),
            audioPaths: List<String>.from(w.audioPaths),
          ),
      ],
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(isEditMode ? l10n.editPhase : l10n.addPhase),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.phaseNameLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: l10n.phaseDescriptionLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InlineDateRangePicker(
                      startDate: startDate,
                      endDate: endDate,
                      onPickStart: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setLocalState(() {
                          startDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                          if (endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      },
                      onPickEnd: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate.isBefore(startDate)
                              ? startDate
                              : endDate,
                          firstDate: startDate,
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setLocalState(() {
                          endDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.assignEmployees),
                    ...team.map(
                      (employee) => CheckboxListTile(
                        value: selectedEmployeeIds.contains(employee.id),
                        title: Text(employee.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setLocalState(() {
                            if (checked == true) {
                              selectedEmployeeIds.add(employee.id);
                            } else {
                              selectedEmployeeIds.remove(employee.id);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    PhaseWorkInstructionsEditor(
                      key: ValueKey(
                        'draft_phase_instr_${existing?.id ?? 'new'}',
                      ),
                      l10n: l10n,
                      readOnly: false,
                      initialItems: draftInstructions.items,
                      onChanged: (s) {
                        setLocalState(() => draftInstructions = s);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final ids = selectedEmployeeIds.toList();
                    final description = descriptionController.text.trim();
                    if (endDate.isBefore(startDate)) return;

                    setState(() {
                      if (isEditMode) {
                        _draftPhases = [
                          for (final p in _draftPhases)
                            if (p.id == existing.id)
                              p.copyWith(
                                name: name,
                                startDate: startDate,
                                endDate: endDate,
                                description: description,
                                assignedEmployeeIds: ids,
                                workInstructions: draftInstructions
                                    .forPersistence(),
                              )
                            else
                              p,
                        ];
                      } else {
                        _draftPhases = [
                          ..._draftPhases,
                          ProjectPhase(
                            id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            startDate: startDate,
                            endDate: endDate,
                            description: description,
                            workInstructions: draftInstructions
                                .forPersistence(),
                            assignedEmployeeIds: ids,
                            status: PhaseStatus.notStarted,
                          ),
                        ];
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(isEditMode ? l10n.saveChanges : l10n.addPhase),
                ),
              ],
            );
          },
        );
      },
    );
    void disposeControllers() {
      nameController.dispose();
      descriptionController.dispose();
    }

    if (!context.mounted) {
      disposeControllers();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => disposeControllers());
  }

  void _save(BuildContext context, {required bool isEdit}) {
    final name = _nameController.text.trim();
    final clientId = _selectedClientId?.trim() ?? '';
    if (name.isEmpty || clientId.isEmpty) return;

    final addressLine1 = _addressLine1Controller.text.trim();
    final city = _cityController.text.trim();
    final stateProvince = _stateController.text.trim();
    final zipCode = _zipCodeController.text.trim();
    if (addressLine1.isEmpty ||
        city.isEmpty ||
        stateProvince.isEmpty ||
        zipCode.isEmpty) {
      return;
    }

    final team = ref.read(teamProvider);
    final phases = isEdit
        ? ref
                  .read(projectsProvider.notifier)
                  .findById(widget.projectId!)
                  ?.phases ??
              const <ProjectPhase>[]
        : List<ProjectPhase>.from(_draftPhases);
    final assignment = _deriveProjectAssignmentsFromPhases(phases, team);

    if (isEdit) {
      ref
          .read(projectsProvider.notifier)
          .updateProject(
            id: widget.projectId!,
            name: name,
            clientId: clientId,
            status: _selectedStatus,
            workers: assignment.workers,
            assignedEmployeeIds: assignment.assignedEmployeeIds,
            useClientAddress: _useClientAddress,
            addressLine1: addressLine1,
            city: city,
            stateProvince: stateProvince,
            zipCode: zipCode,
            phases: phases,
          );
    } else {
      ref
          .read(projectsProvider.notifier)
          .addProject(
            name: name,
            clientId: clientId,
            status: _selectedStatus,
            workers: assignment.workers,
            assignedEmployeeIds: assignment.assignedEmployeeIds,
            useClientAddress: _useClientAddress,
            addressLine1: addressLine1,
            city: city,
            stateProvince: stateProvince,
            zipCode: zipCode,
            phases: phases,
          );
    }

    Navigator.of(context).pop();
  }

  void _syncAddressFromClient() {
    final clientId = _selectedClientId;
    if (clientId == null) return;
    Client? client;
    for (final c in ref.read(clientsProvider)) {
      if (c.id == clientId) {
        client = c;
        break;
      }
    }
    if (client == null) return;
    _addressLine1Controller.text = client.addressLine1;
    _cityController.text = client.city;
    _stateController.text = client.state;
    _zipCodeController.text = client.zipCode;
  }

  /// Derives project-level worker summary from phase-level assignment.
  static ({List<String> workers, List<String> assignedEmployeeIds})
  _deriveProjectAssignmentsFromPhases(
    List<ProjectPhase> phases,
    List<Employee> team,
  ) {
    final namesById = {for (final employee in team) employee.id: employee.name};
    final idSet = <String>{};
    for (final phase in phases) {
      for (final id in phase.assignedEmployeeIds) {
        if (id.trim().isNotEmpty) {
          idSet.add(id);
        }
      }
    }
    final ids = idSet.toList()..sort();
    final workers = <String>[
      for (final id in ids)
        if (namesById.containsKey(id)) namesById[id]!,
    ];
    return (workers: workers, assignedEmployeeIds: ids);
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

class _DraftPhasesList extends StatelessWidget {
  const _DraftPhasesList({
    required this.phases,
    required this.l10n,
    required this.onEdit,
    required this.onRemove,
  });

  final List<ProjectPhase> phases;
  final AppLocalizations l10n;
  final void Function(ProjectPhase phase) onEdit;
  final void Function(String phaseId) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (phases.isEmpty) ...[
          Text(
            l10n.noPhasesYet,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...phases.map(
          (phase) => Dismissible(
            key: ValueKey('draft_phase_${phase.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              onEdit(phase);
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
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(phase.name),
                subtitle: _phaseListSubtitle(context, l10n, phase),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editPhase,
                      onPressed: () => onEdit(phase),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.removePhase,
                      onPressed: () => onRemove(phase.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectPhasesList extends StatelessWidget {
  const _ProjectPhasesList({
    required this.project,
    required this.l10n,
    required this.onEdit,
    required this.onRemove,
    required this.onApprove,
    required this.onReject,
  });

  final Project project;
  final AppLocalizations l10n;
  final void Function(ProjectPhase phase) onEdit;
  final void Function(ProjectPhase phase) onRemove;
  final void Function(ProjectPhase phase) onApprove;
  final void Function(ProjectPhase phase) onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (project.phases.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.noPhasesYet),
          ),
        ...project.phases.map((phase) {
          final card = Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(phase.name),
              subtitle: _phaseListSubtitle(context, l10n, phase),
              trailing: phase.status == PhaseStatus.pendingReview
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: l10n.reject,
                          onPressed: () => onReject(phase),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          tooltip: l10n.approve,
                          onPressed: () => onApprove(phase),
                        ),
                      ],
                    )
                  : phase.status == PhaseStatus.done
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editPhase,
                      onPressed: () => onEdit(phase),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l10n.editPhase,
                          onPressed: () => onEdit(phase),
                        ),
                        if (phase.status == PhaseStatus.notStarted)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.removePhase,
                            onPressed: () => onRemove(phase),
                          ),
                      ],
                    ),
            ),
          );
          if (phase.status == PhaseStatus.pendingReview) {
            return card;
          }
          return Dismissible(
            key: ValueKey('project_phase_${phase.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (direction) async {
              onEdit(phase);
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
            child: card,
          );
        }),
      ],
    );
  }
}

class _MembersByPhaseCard extends StatelessWidget {
  const _MembersByPhaseCard({
    required this.phases,
    required this.employeesById,
  });

  final List<ProjectPhase> phases;
  final Map<String, String> employeesById;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.plannerMembersByPhase,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (phases.isEmpty)
              Text(
                context.l10n.noPhasesYet,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            for (final phase in phases) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(phase.name),
                subtitle: Text(
                  '${localizations.formatMediumDate(phase.startDate)} - ${localizations.formatMediumDate(phase.endDate)}\n'
                  '${phase.assignedEmployeeIds.map((id) => employeesById[id] ?? id).join(', ')}',
                ),
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailySequencePlannerCard extends StatelessWidget {
  const _DailySequencePlannerCard({
    required this.selectedDay,
    required this.onPickDay,
    required this.project,
    required this.team,
    required this.notifier,
  });

  final DateTime selectedDay;
  final ValueChanged<DateTime> onPickDay;
  final Project project;
  final List<Employee> team;
  final ProjectsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final workers = [
      for (final worker in team)
        if (project.phases.any(
          (p) => p.assignedEmployeeIds.contains(worker.id),
        ))
          worker,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.l10n.plannerWorkSequenceForDay} ${localizations.formatMediumDate(selectedDay)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDay,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    onPickDay(DateTime(picked.year, picked.month, picked.day));
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(context.l10n.plannerChangeDay),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (workers.isEmpty)
              Text(context.l10n.plannerNoWorkersAssignedToPhasesYet),
            for (final worker in workers)
              _WorkerDaySequenceRow(
                worker: worker,
                project: project,
                day: selectedDay,
                notifier: notifier,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkerDaySequenceRow extends StatelessWidget {
  const _WorkerDaySequenceRow({
    required this.worker,
    required this.project,
    required this.day,
    required this.notifier,
  });

  final Employee worker;
  final Project project;
  final DateTime day;
  final ProjectsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sequence = notifier.sequenceForDay(
      projectId: project.id,
      workerId: worker.id,
      day: day,
    );
    final suggested = notifier.suggestedSequenceForDay(
      projectId: project.id,
      workerId: worker.id,
      day: day,
    );
    final labelsById = {for (final p in project.phases) p.id: p.name};
    final orderedIds = [
      for (final id in sequence.orderedPhaseIds)
        if (labelsById.containsKey(id)) id,
    ];
    final orderedLabels = [
      for (final id in sequence.orderedPhaseIds)
        if (labelsById.containsKey(id)) labelsById[id]!,
    ];
    final suggestedCount = suggested.orderedPhaseIds
        .where(labelsById.containsKey)
        .length;
    void saveOrder(List<String> ids) {
      notifier.saveDailySequence(
        projectId: project.id,
        workerId: worker.id,
        day: day,
        orderedPhaseIds: ids,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    worker.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(
                    sequence.isManual ? l10n.plannerManual : l10n.plannerAuto,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              sequence.isManual ? l10n.plannerManualHint : l10n.plannerAutoHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (orderedLabels.isEmpty)
              Text(
                suggestedCount == 0
                    ? l10n.plannerNoPhaseForDayWindow
                    : l10n.plannerNoSavedCustomOrder,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.plannerDragToReorderHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: orderedIds.length,
                    onReorder: (oldIndex, newIndex) {
                      final ids = [...orderedIds];
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      saveOrder(ids);
                    },
                    itemBuilder: (context, index) {
                      final phaseId = orderedIds[index];
                      return Card(
                        key: ValueKey('phase_seq_${worker.id}_$phaseId'),
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(labelsById[phaseId] ?? phaseId),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.plannerMoveUp,
                                onPressed: index == 0
                                    ? null
                                    : () {
                                        final ids = [...orderedIds];
                                        final moved = ids.removeAt(index);
                                        ids.insert(index - 1, moved);
                                        saveOrder(ids);
                                      },
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: l10n.plannerMoveDown,
                                onPressed: index == orderedIds.length - 1
                                    ? null
                                    : () {
                                        final ids = [...orderedIds];
                                        final moved = ids.removeAt(index);
                                        ids.insert(index + 1, moved);
                                        saveOrder(ids);
                                      },
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_indicator),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: suggestedCount == 0
                            ? null
                            : () {
                                saveOrder(suggested.orderedPhaseIds);
                              },
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(l10n.plannerUseAutoSuggestion),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: orderedIds.length < 2
                            ? null
                            : () {
                                final ids = [...orderedIds];
                                final moved = ids.removeLast();
                                ids.insert(0, moved);
                                saveOrder(ids);
                              },
                        icon: const Icon(Icons.swap_vert),
                        label: Text(l10n.plannerMoveLastToFirst),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: sequence.isManual
                            ? () {
                                notifier.resetDailySequence(
                                  projectId: project.id,
                                  workerId: worker.id,
                                  day: day,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.plannerResetToAuto),
                      ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: suggestedCount == 0
                          ? null
                          : () {
                              saveOrder(suggested.orderedPhaseIds);
                            },
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(l10n.plannerUseAutoSuggestion),
                    ),
                    OutlinedButton.icon(
                      onPressed: orderedIds.length < 2
                          ? null
                          : () {
                              final ids = [...orderedIds];
                              final moved = ids.removeLast();
                              ids.insert(0, moved);
                              saveOrder(ids);
                            },
                      icon: const Icon(Icons.swap_vert),
                      label: Text(l10n.plannerMoveLastToFirst),
                    ),
                    OutlinedButton.icon(
                      onPressed: sequence.isManual
                          ? () {
                              notifier.resetDailySequence(
                                projectId: project.id,
                                workerId: worker.id,
                                day: day,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.plannerResetToAuto),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDateRangePicker extends StatelessWidget {
  const _InlineDateRangePicker({
    required this.startDate,
    required this.endDate,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPickStart,
            child: Text(
              l10n.plannerFromDate(localizations.formatMediumDate(startDate)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onPickEnd,
            child: Text(
              l10n.plannerToDate(localizations.formatMediumDate(endDate)),
            ),
          ),
        ),
      ],
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

String _phaseStatusLabel(AppLocalizations l10n, PhaseStatus status) {
  return switch (status) {
    PhaseStatus.notStarted => l10n.phaseStatusNotStarted,
    PhaseStatus.inProgress => l10n.statusInProgress,
    PhaseStatus.pendingReview => l10n.phaseStatusPendingReview,
    PhaseStatus.done => l10n.statusDone,
  };
}

Widget _phaseListSubtitle(
  BuildContext context,
  AppLocalizations l10n,
  ProjectPhase phase,
) {
  final desc = phase.description.trim();
  final localizations = MaterialLocalizations.of(context);
  final windowLabel =
      '${localizations.formatMediumDate(phase.startDate)} - ${localizations.formatMediumDate(phase.endDate)}';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${l10n.statusLabel}: ${_phaseStatusLabel(l10n, phase.status)}'
        ' | ${l10n.employeesTitle}: ${phase.assignedEmployeeIds.length}\n'
        '$windowLabel',
      ),
      if (desc.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );
}
