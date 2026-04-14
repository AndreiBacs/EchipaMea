import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../application/foreman_workflow_progress_controller.dart';
import '../../domain/entities/foreman_workflow_step.dart';
import '../providers/projects_controller.dart';
import 'client_form_page.dart';
import 'employee_form_page.dart';
import 'foreman_shell_page.dart';
import 'project_form_page.dart';
import 'project_phase_form_page.dart';

class ForemanGettingStartedPage extends ConsumerWidget {
  const ForemanGettingStartedPage({super.key});

  static const path = '/foreman/getting-started';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workflowState = ref.watch(foremanWorkflowProgressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foremanGettingStartedTitle)),
      body: workflowState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'foreman_getting_started_page',
              context: ErrorDescription(
                'while rendering foreman getting-started screen',
              ),
            ),
          );
          return Center(child: Text(l10n.genericErrorMessage));
        },
        data: (workflow) {
          final steps = ForemanWorkflowStep.values;
          final completedCount = workflow.completedCount;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.foremanGettingStartedDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.foremanGettingStartedProgress(
                  completedCount,
                  steps.length,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: completedCount / steps.length),
              const SizedBox(height: 20),
              for (final step in steps) ...[
                _StepTile(
                  title: _stepTitle(step, l10n),
                  subtitle: _stepDescription(step, l10n),
                  done: workflow.completedSteps.contains(step),
                  onPressed: () => _openStep(context, ref, step),
                  actionLabel: l10n.foremanGettingStartedGo,
                ),
                const SizedBox(height: 12),
              ],
              if (workflow.cardDismissed) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(foremanWorkflowProgressProvider.notifier)
                          .restoreCard();
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.foremanGettingStartedShowCardAgain),
                  ),
                ),
              ],
            ],
          );
        },
      ),
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

  String _stepTitle(ForemanWorkflowStep step, AppLocalizations l10n) {
    return switch (step) {
      ForemanWorkflowStep.addClient => l10n.foremanWorkflowAddClientTitle,
      ForemanWorkflowStep.createProject =>
        l10n.foremanWorkflowCreateProjectTitle,
      ForemanWorkflowStep.configurePhase =>
        l10n.foremanWorkflowConfigurePhaseTitle,
      ForemanWorkflowStep.addEmployee => l10n.foremanWorkflowAddEmployeeTitle,
    };
  }

  String _stepDescription(ForemanWorkflowStep step, AppLocalizations l10n) {
    return switch (step) {
      ForemanWorkflowStep.addClient => l10n.foremanWorkflowAddClientDescription,
      ForemanWorkflowStep.createProject =>
        l10n.foremanWorkflowCreateProjectDescription,
      ForemanWorkflowStep.configurePhase =>
        l10n.foremanWorkflowConfigurePhaseDescription,
      ForemanWorkflowStep.addEmployee =>
        l10n.foremanWorkflowAddEmployeeDescription,
    };
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onPressed,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onPressed;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green : null,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ),
    );
  }
}
