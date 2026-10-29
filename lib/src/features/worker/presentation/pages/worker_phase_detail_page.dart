import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/async_status_view.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../providers/worker_assigned_projects_provider.dart';
import '../widgets/phase_work_instructions_panel.dart';
import 'worker_report_flow_page.dart';

class WorkerPhaseDetailPage extends ConsumerWidget {
  const WorkerPhaseDetailPage({
    super.key,
    required this.projectId,
    required this.phaseId,
  });

  static String pathFor({required String projectId, required String phaseId}) =>
      '/worker/project/$projectId/phase/$phaseId';

  final String projectId;
  final String phaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider).value;
    final assignedState = ref.watch(workerAssignedProjectsProvider);
    final assigned = assignedState.current;
    final project = assigned?.where((p) => p.id == projectId).firstOrNull;

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workerProjectDetails)),
        body: assigned == null
            ? AsyncStatusView(
                assignedState,
                onRetry: () => ref.invalidate(workerAssignedProjectsProvider),
              )
            : Center(child: Text(l10n.workerProjectNotFound)),
      );
    }

    final phase = project.phases
        .where((p) => p.id == phaseId)
        .where((p) => p.assignedEmployeeIds.contains(session.employeeId))
        .firstOrNull;

    if (phase == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workerProjectDetails)),
        body: Center(child: Text(l10n.workerProjectNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(phase.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(project.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${l10n.statusLabel}: ${_phaseStatusLabel(l10n, phase.status)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (phase.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              phase.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 20),
          PhaseWorkInstructionsPanel(l10n: l10n, phase: phase),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push(
              WorkerReportFlowPage.pathFor(
                projectId: project.id,
                phaseId: phase.id,
              ),
            ),
            icon: const Icon(Icons.task_alt),
            label: Text(l10n.workerCompleteWork),
          ),
          const SizedBox(height: 12),
          if (phase.status != PhaseStatus.pendingReview &&
              phase.status != PhaseStatus.done)
            FilledButton.tonalIcon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(workerAssignedProjectsProvider.notifier)
                      .submitPhase(projectId: project.id, phaseId: phase.id);
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.phaseSubmittedForReview)),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(apiErrorMessage(l10n, error))),
                  );
                }
              },
              icon: const Icon(Icons.task_alt_outlined),
              label: Text(l10n.workerSubmitForReview),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  static String _phaseStatusLabel(AppLocalizations l10n, PhaseStatus status) {
    return switch (status) {
      PhaseStatus.notStarted => l10n.phaseStatusNotStarted,
      PhaseStatus.inProgress => l10n.statusInProgress,
      PhaseStatus.pendingReview => l10n.phaseStatusPendingReview,
      PhaseStatus.done => l10n.statusDone,
    };
  }
}
