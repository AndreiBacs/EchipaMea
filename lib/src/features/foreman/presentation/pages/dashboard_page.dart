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
import 'foreman_shell_page.dart';
import 'project_form_page.dart';
import 'project_phase_form_page.dart';
import '../providers/projects_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    const employees = [
      _EmployeeAssignment(
        employeeName: 'Andrei D.',
        role: WorkerRole.electrician,
        projectName: 'Renovation - Main Street 15',
        currentTask: 'Wiring floor 2',
      ),
      _EmployeeAssignment(
        employeeName: 'Mihai S.',
        role: WorkerRole.plumber,
        projectName: 'Kitchen fit-out - Cafe Luna',
        currentTask: 'Install sink lines',
      ),
      _EmployeeAssignment(
        employeeName: 'Ioana R.',
        role: WorkerRole.generalWorker,
        projectName: 'Roof repair - Industrial Hall',
        currentTask: 'Material prep and transport',
      ),
      _EmployeeAssignment(
        employeeName: 'Vlad P.',
        role: WorkerRole.carpenter,
        projectName: 'Renovation - Main Street 15',
        currentTask: 'Build partition walls',
      ),
    ];

    const projectAllocations = [
      _ProjectAllocation(
        projectName: 'Renovation - Main Street 15',
        workers: ['Andrei D.', 'Vlad P.'],
      ),
      _ProjectAllocation(
        projectName: 'Kitchen fit-out - Cafe Luna',
        workers: ['Mihai S.'],
      ),
      _ProjectAllocation(
        projectName: 'Roof repair - Industrial Hall',
        workers: ['Ioana R.'],
      ),
    ];

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
                    value: '${employees.length}',
                    subtitle: l10n.totalWorkersAvailable,
                  ),
                  _KpiCard(
                    title: l10n.inProgress,
                    value: '${projectAllocations.length}',
                    subtitle: l10n.activeProjectsNow,
                  ),
                  _KpiCard(
                    title: l10n.assignments,
                    value: '${employees.length}',
                    subtitle: l10n.workersWithActiveTasks,
                  ),
                  _KpiCard(
                    title: l10n.clientsTitle,
                    value: '${projectAllocations.length}',
                    subtitle: l10n.clientsWithActiveJobs,
                  ),
                ]),
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
                  final item = employees[index];
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
                }, childCount: employees.length),
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
                24,
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
          ],
        );
      },
    );
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
              final messenger = ScaffoldMessenger.maybeOf(rootNavigator.context);
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
      error: (_, __) => const SizedBox.shrink(),
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
