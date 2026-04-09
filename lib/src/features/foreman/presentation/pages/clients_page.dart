import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'client_form_page.dart';
import '../providers/clients_controller.dart';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            runSpacing: 8,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isTablet ? 400 : MediaQuery.sizeOf(context).width - 64,
                child: Text(
                  'Clients (${clients.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(ClientFormPage.createPath),
                icon: const Icon(Icons.add),
                label: const Text('Add client'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 8,
              vertical: 8,
            ),
            itemCount: clients.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(client.name),
                subtitle: Text(client.activeProjectsLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit client',
                  onPressed: () =>
                      context.push('/foreman/clients/${client.id}/edit'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
