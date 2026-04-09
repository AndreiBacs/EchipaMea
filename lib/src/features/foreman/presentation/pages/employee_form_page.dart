import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'foreman_shell_page.dart';
import '../providers/team_controller.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, this.employeeId});

  static const createPath = '/foreman/team/new';
  static const editPath = '/foreman/team/:id/edit';

  final String? employeeId;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    final existing = widget.employeeId == null
        ? null
        : ref.read(teamProvider.notifier).findById(widget.employeeId!);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _roleController = TextEditingController(text: existing?.role ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employeeId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit employee' : 'Add employee')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Employee name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go(ForemanShellPage.teamPath),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(context, isEdit: isEdit),
                    child: Text(isEdit ? 'Save changes' : 'Create employee'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save(BuildContext context, {required bool isEdit}) {
    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    if (name.isEmpty || role.isEmpty) return;

    if (isEdit) {
      ref
          .read(teamProvider.notifier)
          .updateEmployee(id: widget.employeeId!, name: name, role: role);
    } else {
      ref.read(teamProvider.notifier).addEmployee(name: name, role: role);
    }

    Navigator.of(context).pop();
  }
}
