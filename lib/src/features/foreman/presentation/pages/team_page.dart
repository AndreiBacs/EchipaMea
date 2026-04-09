import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:convert';

import 'employee_form_page.dart';
import '../providers/team_controller.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(teamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Employees (${employees.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(EmployeeFormPage.createPath),
                icon: const Icon(Icons.add),
                label: const Text('Add employee'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: employees.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                leading: CircleAvatar(child: Text(employee.initials)),
                title: Text(employee.name),
                subtitle: Text(employee.role),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_2),
                      tooltip: 'Generate login QR',
                      onPressed: () => _showEmployeeQrDialog(context, employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit employee',
                      onPressed: () =>
                          context.push('/foreman/team/${employee.id}/edit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEmployeeQrDialog(
    BuildContext context,
    Employee employee,
  ) async {
    final payload = jsonEncode({
      'type': 'employee_login',
      'employeeId': employee.id,
      'employeeName': employee.name,
      'issuedAt': DateTime.now().toIso8601String(),
    });

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Employee login QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                employee.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              QrImageView(data: payload, size: 220),
              const SizedBox(height: 8),
              const Text(
                'Worker scans this code to connect automatically.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
