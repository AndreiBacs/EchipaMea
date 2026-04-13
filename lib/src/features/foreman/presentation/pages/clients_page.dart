import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/app_localizations.dart';
import 'client_form_page.dart';
import 'client_projects_page.dart';
import '../providers/clients_controller.dart';
import '../providers/projects_controller.dart';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final projects = ref.watch(projectsProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    final l10n = context.l10n;
    // Precompute once so each row renders in O(1) instead of O(projects).
    final projectsByClientId = <String, List<Project>>{};
    for (final project in projects) {
      projectsByClientId.putIfAbsent(project.clientId, () => []).add(project);
    }

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
                  final allocatedProjects =
                      projectsByClientId[client.id] ?? const [];
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
                                  Text(
                                    allocatedProjects.length == 1
                                        ? l10n.oneActiveProject
                                        : '${allocatedProjects.length} ${l10n.manyActiveProjects}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${l10n.contactPersonLabel}: ${client.contactPerson}',
                              ),
                              Text('${l10n.profileEmailLabel}: ${client.email}'),
                              Text('${l10n.profilePhoneLabel}: ${client.phone}'),
                              Text(
                                '${l10n.typeLabel}: ${_clientTypeLabel(client.type, l10n)}',
                              ),
                              Text(
                                '${l10n.statusLabel}: ${_clientStatusLabel(client.status, l10n)}',
                              ),
                              Text(
                                '${l10n.preferredContactMethodLabel}: ${_contactMethodLabel(client.preferredContactMethod, l10n)}',
                              ),
                              Text('${l10n.addressLabel}: ${client.fullAddress}'),
                              if (client.notes.trim().isNotEmpty)
                                Text('${l10n.notesLabel}: ${client.notes}'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: l10n.callClientTooltip,
                                    onPressed: () =>
                                        _openPhoneCall(context, client.phone),
                                    icon: const Icon(Icons.call_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.messageClientTooltip,
                                    onPressed: () =>
                                        _openSms(context, client.phone),
                                    icon: const Icon(Icons.sms_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.whatsAppClientTooltip,
                                    onPressed: () =>
                                        _openWhatsApp(context, client.phone),
                                    icon: const Icon(Icons.chat_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.emailClientTooltip,
                                    onPressed: () =>
                                        _openEmail(context, client.email),
                                    icon: const Icon(Icons.email_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.openClientMapTooltip,
                                    onPressed: () =>
                                        _openMap(context, client.fullAddress),
                                    icon: const Icon(Icons.map_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.copyClientPhoneTooltip,
                                    onPressed: () =>
                                        _copyToClipboard(context, client.phone),
                                    icon: const Icon(Icons.content_copy_outlined),
                                  ),
                                  IconButton(
                                    tooltip: l10n.copyClientEmailTooltip,
                                    onPressed: () =>
                                        _copyToClipboard(context, client.email),
                                    icon: const Icon(Icons.alternate_email),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                allocatedProjects.isEmpty
                                    ? l10n.noProjectsAllocated
                                    : '${l10n.allocatedProjectsLabel}: ${allocatedProjects.map((project) => project.name).join(', ')}',
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.editClientTooltip,
                              onPressed: () =>
                                  context.push('/foreman/clients/${client.id}/edit'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.list_alt_outlined),
                              tooltip: l10n.viewClientProjects,
                              onPressed: () => context.push(
                                ClientProjectsPage.path.replaceFirst(
                                  ':id',
                                  client.id,
                                ),
                              ),
                            ),
                          ],
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

  static String _clientTypeLabel(ClientType type, AppLocalizations l10n) {
    return switch (type) {
      ClientType.individual => l10n.clientTypeIndividual,
      ClientType.company => l10n.clientTypeCompany,
      ClientType.publicInstitution => l10n.clientTypePublicInstitution,
    };
  }

  static String _clientStatusLabel(ClientStatus status, AppLocalizations l10n) {
    return switch (status) {
      ClientStatus.active => l10n.statusActive,
      ClientStatus.inactive => l10n.statusInactive,
      ClientStatus.blocked => l10n.statusBlocked,
    };
  }

  static String _contactMethodLabel(
    ClientContactMethod method,
    AppLocalizations l10n,
  ) {
    return switch (method) {
      ClientContactMethod.phone => l10n.contactMethodPhone,
      ClientContactMethod.email => l10n.contactMethodEmail,
      ClientContactMethod.whatsApp => l10n.contactMethodWhatsApp,
    };
  }

  static Future<void> _openPhoneCall(
    BuildContext context,
    String rawPhone,
  ) async {
    final l10n = context.l10n;
    final phone = rawPhone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenDialer)));
  }

  static Future<void> _openSms(BuildContext context, String rawPhone) async {
    final l10n = context.l10n;
    final phone = rawPhone.replaceAll(' ', '');
    final uri = Uri(scheme: 'sms', path: phone);
    final launched = await launchUrl(uri);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMessaging)));
  }

  static Future<void> _openWhatsApp(
    BuildContext context,
    String rawPhone,
  ) async {
    final l10n = context.l10n;
    final phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final normalized = phone.startsWith('+') ? phone.substring(1) : phone;
    final uri = Uri.parse('https://wa.me/$normalized');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenWhatsApp)));
  }

  static Future<void> _openEmail(BuildContext context, String email) async {
    final l10n = context.l10n;
    final uri = Uri(scheme: 'mailto', path: email.trim());
    final launched = await launchUrl(uri);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenEmailApp)));
  }

  static Future<void> _openMap(BuildContext context, String address) async {
    final l10n = context.l10n;
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.couldNotOpenMapApp)));
  }

  static Future<void> _copyToClipboard(BuildContext context, String value) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
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
