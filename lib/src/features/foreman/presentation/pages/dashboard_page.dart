import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/worker_role.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../application/foreman_workflow_progress_controller.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import 'client_form_page.dart';
import 'employee_form_page.dart';
import 'foreman_getting_started_page.dart';
import 'foreman_map_page.dart';
import 'foreman_shell_page.dart';
import 'project_form_page.dart';
import 'project_phase_form_page.dart';
import '../providers/projects_controller.dart';
import '../providers/team_controller.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

enum _FinishedProjectsPeriod { thisMonth, lastMonth, custom }

class _DashboardPageState extends ConsumerState<DashboardPage> {
  _FinishedProjectsPeriod _finishedProjectsPeriod =
      _FinishedProjectsPeriod.thisMonth;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final team = ref.watch(teamProvider);
    final projects = ref.watch(projectsProvider);
    final projectsNotifier = ref.read(projectsProvider.notifier);
    final employeesById = {for (final e in team) e.id: e};
    final today = DateTime.now();

    final employeeAssignments = <_EmployeeAssignment>[];
    for (final project in projects) {
      for (final phase in project.phases) {
        for (final employeeId in phase.assignedEmployeeIds) {
          final employee = employeesById[employeeId];
          if (employee == null) continue;
          employeeAssignments.add(
            _EmployeeAssignment(
              employeeName: employee.name,
              role: employee.role,
              projectName: project.name,
              currentTask: phase.name,
            ),
          );
        }
      }
    }

    final projectAllocations = [
      for (final project in projects)
        _ProjectAllocation(projectName: project.name, workers: project.workers),
    ];
    final uniqueWorkersWithActiveTasks = <String>{};
    for (final project in projects) {
      if (project.status == ProjectStatus.done) continue;
      for (final phase in project.phases) {
        if (phase.status == PhaseStatus.done) continue;
        for (final employeeId in phase.assignedEmployeeIds) {
          uniqueWorkersWithActiveTasks.add(employeeId);
        }
      }
    }
    final activeClientIds = <String>{
      for (final project in projects)
        if (project.status == ProjectStatus.inProgress) project.clientId,
    };
    final finishedProjectsCount = _countFinishedProjects(projects);

    final workflowState = ref.watch(foremanWorkflowProgressProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxContentWidth = width > 1100 ? 1100.0 : width;
        final horizontalMargin = (width - maxContentWidth) / 2;
        final crossAxisCount = maxContentWidth >= 900 ? 4 : 2;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                16,
                horizontalMargin + 16,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _GettingStartedCard(
                  state: workflowState,
                  onContinue: (step) => _openStep(context, ref, step),
                  onViewAll: () => context.push(ForemanGettingStartedPage.path),
                  onDismiss: () {
                    ref
                        .read(foremanWorkflowProgressProvider.notifier)
                        .dismissCard();
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                12,
                horizontalMargin + 16,
                0,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  _KpiCard(
                    title: l10n.employeesTitle,
                    value: '${team.length}',
                    subtitle: l10n.totalWorkersAvailable,
                  ),
                  _KpiCard(
                    title: l10n.inProgress,
                    value:
                        '${projects.where((p) => p.status == ProjectStatus.inProgress).length}',
                    subtitle: l10n.activeProjectsNow,
                  ),
                  _KpiCard(
                    title: l10n.assignments,
                    value: '${uniqueWorkersWithActiveTasks.length}',
                    subtitle: l10n.workersWithActiveTasks,
                  ),
                  _KpiCard(
                    title: l10n.clientsTitle,
                    value: '${activeClientIds.length}',
                    subtitle: l10n.clientsWithActiveJobs,
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                12,
                horizontalMargin + 16,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _FinishedProjectsCard(
                  count: finishedProjectsCount,
                  selectedPeriod: _finishedProjectsPeriod,
                  customRange: _customRange,
                  onPeriodChanged: (period) {
                    setState(() => _finishedProjectsPeriod = period);
                  },
                  onPickCustomRange: () async {
                    final now = DateTime.now();
                    final initial =
                        _customRange ??
                        DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: now,
                        );
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: initial,
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _customRange = DateTimeRange(
                        start: DateTime(
                          picked.start.year,
                          picked.start.month,
                          picked.start.day,
                        ),
                        end: DateTime(
                          picked.end.year,
                          picked.end.month,
                          picked.end.day,
                        ),
                      );
                      _finishedProjectsPeriod = _FinishedProjectsPeriod.custom;
                    });
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                16,
                horizontalMargin + 16,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.whoDoesWhat,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalMargin + 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = employeeAssignments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(item.employeeName.substring(0, 1)),
                        ),
                        title: Text(
                          '${item.employeeName} - ${item.role.localizedLabel(l10n)}',
                        ),
                        subtitle: Text(
                          '${item.currentTask}\n${l10n.projectLabel}: ${item.projectName}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  );
                }, childCount: employeeAssignments.length),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                16,
                horizontalMargin + 16,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.dashboardTodayWorkerSequence,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalMargin + 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final employee = team[index];
                  final sequenceRows = <String>[];
                  String? targetProjectId;
                  for (final project in projects) {
                    final sequence = projectsNotifier.sequenceForDay(
                      projectId: project.id,
                      workerId: employee.id,
                      day: today,
                    );
                    if (sequence.orderedPhaseIds.isEmpty) continue;
                    final namesById = {
                      for (final phase in project.phases) phase.id: phase.name,
                    };
                    final phaseNames = [
                      for (final phaseId in sequence.orderedPhaseIds)
                        if (namesById.containsKey(phaseId)) namesById[phaseId]!,
                    ];
                    if (phaseNames.isEmpty) continue;
                    targetProjectId ??= project.id;
                    sequenceRows.add(
                      '${project.name}: ${phaseNames.join(' -> ')}',
                    );
                  }
                  if (targetProjectId == null) {
                    for (final project in projects) {
                      final hasAssignedPhase = project.phases.any(
                        (phase) =>
                            phase.assignedEmployeeIds.contains(employee.id),
                      );
                      if (hasAssignedPhase) {
                        targetProjectId = project.id;
                        break;
                      }
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: targetProjectId == null
                        ? Card(
                            child: ListTile(
                              title: Text(employee.name),
                              subtitle: Text(
                                sequenceRows.isEmpty
                                    ? l10n.dashboardNoSequencePlannedToday
                                    : sequenceRows.join('\n'),
                              ),
                              isThreeLine: sequenceRows.length > 1,
                              trailing: TextButton(
                                onPressed: null,
                                child: Text(l10n.dashboardPlan),
                              ),
                            ),
                          )
                        : Dismissible(
                            key: ValueKey(
                              'sequence_plan_${employee.id}_$targetProjectId',
                            ),
                            direction: DismissDirection.horizontal,
                            confirmDismiss: (_) async {
                              context.push(
                                ProjectFormPage.editPathWithPhasesTab(
                                  targetProjectId!,
                                ),
                              );
                              return false;
                            },
                            background: _SwipePlanBackground(
                              alignment: Alignment.centerLeft,
                              label: l10n.dashboardPlan,
                            ),
                            secondaryBackground: _SwipePlanBackground(
                              alignment: Alignment.centerRight,
                              label: l10n.dashboardPlan,
                            ),
                            child: Card(
                              child: ListTile(
                                title: Text(employee.name),
                                subtitle: Text(
                                  sequenceRows.isEmpty
                                      ? l10n.dashboardNoSequencePlannedToday
                                      : sequenceRows.join('\n'),
                                ),
                                isThreeLine: sequenceRows.length > 1,
                                trailing: TextButton(
                                  onPressed: () => context.push(
                                    ProjectFormPage.editPathWithPhasesTab(
                                      targetProjectId!,
                                    ),
                                  ),
                                  child: Text(l10n.dashboardPlan),
                                ),
                              ),
                            ),
                          ),
                  );
                }, childCount: team.length),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                16,
                horizontalMargin + 16,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.whoWorksOnWhatProject,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                0,
                horizontalMargin + 16,
                12,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final project = projectAllocations[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.projectName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${project.workers.length} ${l10n.workerCountSuffix}: ${project.workers.join(', ')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: projectAllocations.length),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                0,
                horizontalMargin + 16,
                24,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.dashboardMapSectionTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 420,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: const ForemanMapPage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalMargin + 16,
                0,
                horizontalMargin + 16,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.go(ForemanShellPage.projectsPath),
                    child: Text(l10n.dashboardOpenFullProjectPlanning),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _countFinishedProjects(List<Project> projects) {
    final range = _selectedFinishedRange();
    var count = 0;
    for (final project in projects) {
      if (project.status != ProjectStatus.done) continue;
      final finishedAt = _projectFinishedAt(project);
      if (finishedAt == null) continue;
      if (finishedAt.isBefore(range.start) || finishedAt.isAfter(range.end)) {
        continue;
      }
      count += 1;
    }
    return count;
  }

  DateTimeRange _selectedFinishedRange() {
    final now = DateTime.now();
    if (_finishedProjectsPeriod == _FinishedProjectsPeriod.custom &&
        _customRange != null) {
      return _customRange!;
    }
    if (_finishedProjectsPeriod == _FinishedProjectsPeriod.lastMonth) {
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));
      final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
      return DateTimeRange(start: lastMonthStart, end: lastMonthEnd);
    }
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTime? _projectFinishedAt(Project project) {
    DateTime? latestReview;
    for (final phase in project.phases) {
      final reviewedAt = phase.reviewedAt;
      if (reviewedAt == null) continue;
      if (latestReview == null || reviewedAt.isAfter(latestReview)) {
        latestReview = reviewedAt;
      }
    }
    if (latestReview != null) {
      return DateTime(latestReview.year, latestReview.month, latestReview.day);
    }
    if (project.phases.isEmpty) return null;
    DateTime latestEnd = project.phases.first.endDate;
    for (final phase in project.phases) {
      if (phase.endDate.isAfter(latestEnd)) {
        latestEnd = phase.endDate;
      }
    }
    return DateTime(latestEnd.year, latestEnd.month, latestEnd.day);
  }

  void _openStep(
    BuildContext context,
    WidgetRef ref,
    ForemanWorkflowStep step,
  ) {
    switch (step) {
      case ForemanWorkflowStep.addClient:
        context.push(ClientFormPage.createPath);
      case ForemanWorkflowStep.createProject:
        context.push(ProjectFormPage.createPath);
      case ForemanWorkflowStep.configurePhase:
        final projects = ref.read(projectsProvider);
        if (projects.isEmpty) {
          final phaseHint = context.l10n.foremanGettingStartedPhaseHint;
          final rootNavigator = Navigator.of(context, rootNavigator: true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(ForemanShellPage.projectsPath);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final messenger = ScaffoldMessenger.maybeOf(
                rootNavigator.context,
              );
              if (messenger == null) return;
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(phaseHint)));
            });
          });
          return;
        }
        final path = ProjectPhaseFormPage.newPath.replaceFirst(
          ':projectId',
          projects.first.id,
        );
        context.push(path);
      case ForemanWorkflowStep.addEmployee:
        context.push(EmployeeFormPage.createPath);
    }
  }
}

class _FinishedProjectsCard extends StatelessWidget {
  const _FinishedProjectsCard({
    required this.count,
    required this.selectedPeriod,
    required this.customRange,
    required this.onPeriodChanged,
    required this.onPickCustomRange,
  });

  final int count;
  final _FinishedProjectsPeriod selectedPeriod;
  final DateTimeRange? customRange;
  final ValueChanged<_FinishedProjectsPeriod> onPeriodChanged;
  final VoidCallback onPickCustomRange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localizations = MaterialLocalizations.of(context);
    final rangeLabel = customRange == null
        ? l10n.dashboardFinishedProjectsNoCustomRange
        : '${localizations.formatMediumDate(customRange!.start)} - ${localizations.formatMediumDate(customRange!.end)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dashboardFinishedProjectsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(l10n.dashboardFinishedProjectsSubtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.dashboardPeriodThisMonth),
                  selected: selectedPeriod == _FinishedProjectsPeriod.thisMonth,
                  onSelected: (_) =>
                      onPeriodChanged(_FinishedProjectsPeriod.thisMonth),
                ),
                ChoiceChip(
                  label: Text(l10n.dashboardPeriodLastMonth),
                  selected: selectedPeriod == _FinishedProjectsPeriod.lastMonth,
                  onSelected: (_) =>
                      onPeriodChanged(_FinishedProjectsPeriod.lastMonth),
                ),
                ChoiceChip(
                  label: Text(l10n.dashboardPeriodCustom),
                  selected: selectedPeriod == _FinishedProjectsPeriod.custom,
                  onSelected: (_) =>
                      onPeriodChanged(_FinishedProjectsPeriod.custom),
                ),
              ],
            ),
            if (selectedPeriod == _FinishedProjectsPeriod.custom) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickCustomRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(l10n.dashboardSelectCustomPeriod),
                  ),
                  Text(
                    rangeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _EmployeeAssignment {
  const _EmployeeAssignment({
    required this.employeeName,
    required this.role,
    required this.projectName,
    required this.currentTask,
  });

  final String employeeName;
  final WorkerRole role;
  final String projectName;
  final String currentTask;
}

class _ProjectAllocation {
  const _ProjectAllocation({required this.projectName, required this.workers});

  final String projectName;
  final List<String> workers;
}

class _SwipePlanBackground extends StatelessWidget {
  const _SwipePlanBackground({required this.alignment, required this.label});

  final Alignment alignment;
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
          Icon(
            Icons.event_note_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
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

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({
    required this.state,
    required this.onContinue,
    required this.onViewAll,
    required this.onDismiss,
  });

  final AsyncValue<ForemanWorkflowProgressState> state;
  final ValueChanged<ForemanWorkflowStep> onContinue;
  final VoidCallback onViewAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (workflow) {
        if (workflow.cardDismissed || workflow.allStepsCompleted) {
          return const SizedBox.shrink();
        }
        final nextStep = ForemanWorkflowStep.values.firstWhere(
          (step) => !workflow.completedSteps.contains(step),
          orElse: () => ForemanWorkflowStep.addClient,
        );
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.foremanGettingStartedTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.foremanGettingStartedProgress(
                    workflow.completedCount,
                    ForemanWorkflowStep.values.length,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value:
                      workflow.completedCount /
                      ForemanWorkflowStep.values.length,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.foremanGettingStartedNext(_stepLabel(nextStep, l10n)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => onContinue(nextStep),
                      child: Text(l10n.foremanGettingStartedContinue),
                    ),
                    OutlinedButton(
                      onPressed: onViewAll,
                      child: Text(l10n.foremanGettingStartedViewAll),
                    ),
                    TextButton(
                      onPressed: onDismiss,
                      child: Text(l10n.foremanGettingStartedDismiss),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _stepLabel(ForemanWorkflowStep step, AppLocalizations l10n) {
    return switch (step) {
      ForemanWorkflowStep.addClient => l10n.foremanWorkflowAddClientTitle,
      ForemanWorkflowStep.createProject =>
        l10n.foremanWorkflowCreateProjectTitle,
      ForemanWorkflowStep.configurePhase =>
        l10n.foremanWorkflowConfigurePhaseTitle,
      ForemanWorkflowStep.addEmployee => l10n.foremanWorkflowAddEmployeeTitle,
    };
  }
}
