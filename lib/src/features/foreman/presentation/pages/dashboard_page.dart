import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const employees = [
      _EmployeeAssignment(
        employeeName: 'Andrei D.',
        role: 'Electrician',
        projectName: 'Renovation - Main Street 15',
        currentTask: 'Wiring floor 2',
      ),
      _EmployeeAssignment(
        employeeName: 'Mihai S.',
        role: 'Plumber',
        projectName: 'Kitchen fit-out - Cafe Luna',
        currentTask: 'Install sink lines',
      ),
      _EmployeeAssignment(
        employeeName: 'Ioana R.',
        role: 'General Worker',
        projectName: 'Roof repair - Industrial Hall',
        currentTask: 'Material prep and transport',
      ),
      _EmployeeAssignment(
        employeeName: 'Vlad P.',
        role: 'Carpenter',
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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            delegate: SliverChildListDelegate([
              _KpiCard(
                title: 'Employees',
                value: '${employees.length}',
                subtitle: 'Total workers available',
              ),
              _KpiCard(
                title: 'In Progress',
                value: '${projectAllocations.length}',
                subtitle: 'Active projects now',
              ),
            ]),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Who does what',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    title: Text('${item.employeeName} - ${item.role}'),
                    subtitle: Text(
                      '${item.currentTask}\nProject: ${item.projectName}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              );
            }, childCount: employees.length),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Who works on what project',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                          '${project.workers.length} worker(s): ${project.workers.join(', ')}',
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
  final String role;
  final String projectName;
  final String currentTask;
}

class _ProjectAllocation {
  const _ProjectAllocation({required this.projectName, required this.workers});

  final String projectName;
  final List<String> workers;
}
