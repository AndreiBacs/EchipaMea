import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'client_form_page.dart';
import '../providers/clients_controller.dart';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    final l10n = context.l10n;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: isTablet ? 400 : MediaQuery.sizeOf(context).width - 64,
                child: Text(
                  '${l10n.clientsTitle} (${clients.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 8,
                  8,
                  isTablet ? 24 : 8,
                  96,
                ),
                itemCount: clients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return Dismissible(
                    key: ValueKey('client_${client.id}'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      context.push('/foreman/clients/${client.id}/edit');
                      return false;
                    },
                    background: _SwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      icon: Icons.edit_outlined,
                      label: l10n.quickEdit,
                    ),
                    secondaryBackground: _SwipeActionBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.edit_outlined,
                      label: l10n.quickEdit,
                    ),
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          child: Text(_initials(client.name)),
                        ),
                        title: Text(
                          client.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  Text(client.activeProjectsLabel),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${l10n.contactPersonLabel}: ${client.contactPerson}',
                              ),
                              Text('${l10n.profileEmailLabel}: ${client.email}'),
                              Text('${l10n.profilePhoneLabel}: ${client.phone}'),
                              Text('${l10n.addressLabel}: ${client.address}'),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: l10n.editClientTooltip,
                          onPressed: () =>
                              context.push('/foreman/clients/${client.id}/edit'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => context.push(ClientFormPage.createPath),
            icon: const Icon(Icons.add),
            label: Text(l10n.addClient),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
