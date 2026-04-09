import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'foreman_shell_page.dart';
import '../providers/clients_controller.dart';

class ClientFormPage extends ConsumerStatefulWidget {
  const ClientFormPage({super.key, this.clientId});

  static const createPath = '/foreman/clients/new';
  static const editPath = '/foreman/clients/:id/edit';

  final String? clientId;

  @override
  ConsumerState<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends ConsumerState<ClientFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _activeProjectsController;

  @override
  void initState() {
    super.initState();
    final existing = widget.clientId == null
        ? null
        : ref.read(clientsProvider.notifier).findById(widget.clientId!);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _activeProjectsController = TextEditingController(
      text: existing?.activeProjects.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _activeProjectsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.clientId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit client' : 'Add client')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Client name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _activeProjectsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Active projects'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go(ForemanShellPage.clientsPath),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(context, isEdit: isEdit),
                    child: Text(isEdit ? 'Save changes' : 'Create client'),
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
    final activeProjects = int.tryParse(_activeProjectsController.text.trim());
    if (name.isEmpty || activeProjects == null || activeProjects < 0) return;

    if (isEdit) {
      ref
          .read(clientsProvider.notifier)
          .updateClient(
            id: widget.clientId!,
            name: name,
            activeProjects: activeProjects,
          );
    } else {
      ref
          .read(clientsProvider.notifier)
          .addClient(name: name, activeProjects: activeProjects);
    }

    Navigator.of(context).pop();
  }
}
