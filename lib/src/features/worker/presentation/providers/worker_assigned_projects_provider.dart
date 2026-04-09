import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../../../foreman/presentation/providers/team_controller.dart';
import 'worker_completed_projects_provider.dart';

/// Projects assigned to the signed-in worker (by roster employee ID when set on
/// the project, otherwise by display name on the worker list).
final workerAssignedProjectsProvider = Provider<List<Project>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return const [];

  final team = ref.watch(teamProvider);
  Employee? employee;
  for (final e in team) {
    if (e.id == session.employeeId) {
      employee = e;
      break;
    }
  }

  final completedLocally = ref.watch(workerCompletedProjectIdsProvider);

  final projects = ref.watch(projectsProvider);
  final mine = projects.where((p) {
    if (p.status == ProjectStatus.done) return false;
    if (completedLocally.contains(p.id)) return false;
    if (p.assignedEmployeeIds.contains(session.employeeId)) return true;
    final displayName = employee?.name ?? session.employeeName;
    final normalized = displayName.trim().toLowerCase();
    return p.workers.any((w) => w.trim().toLowerCase() == normalized);
  }).toList();

  int sortKey(Project p) {
    return switch (p.status) {
      ProjectStatus.inProgress => 0,
      ProjectStatus.planned => 1,
      ProjectStatus.done => 2,
    };
  }

  mine.sort((a, b) {
    final byStatus = sortKey(a).compareTo(sortKey(b));
    if (byStatus != 0) return byStatus;
    return a.name.compareTo(b.name);
  });
  return mine;
});
