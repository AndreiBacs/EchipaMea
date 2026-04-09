import 'package:flutter/material.dart';

import '../../../../core/domain/entities/worker_role.dart';
import '../../../../core/i18n/app_localizations.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
