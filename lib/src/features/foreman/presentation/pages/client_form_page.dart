import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import '../../../../core/ui/app_international_phone_field.dart';
import '../../../../core/ui/async_status_view.dart';
import '../../domain/romanian_counties.dart';
import 'foreman_shell_page.dart';
import '../providers/clients_controller.dart';

class ClientFormPage extends ConsumerWidget {
  const ClientFormPage({super.key, this.clientId});

  static const createPath = '/foreman/clients/new';
  static const editPath = '/foreman/clients/:id/edit';

  final String? clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = clientId;
    if (id == null) return const _ClientForm(existing: null);

    // Resolved before the form is built, because the form copies the client
    // into its fields once, in initState.
    final l10n = context.l10n;
    final clientsState = ref.watch(clientsProvider);
    final clients = clientsState.current;
    final existing = clients?.where((c) => c.id == id).firstOrNull;
    if (existing != null) {
      return _ClientForm(key: ValueKey(id), existing: existing);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.clientFormEditTitle)),
      body: clients == null
          ? AsyncStatusView(
              clientsState,
              onRetry: () => ref.invalidate(clientsProvider),
            )
          : Center(child: Text(l10n.apiErrorNotFound)),
    );
  }
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({super.key, required this.existing});

  /// Null when adding a client.
  final Client? existing;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _notesController;
  String? _selectedStateProvince;
  late ClientType _selectedClientType;
  late ClientStatus _selectedClientStatus;
  late ClientContactMethod _selectedContactMethod;
  String _internationalPhone = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _selectedClientType = existing?.type ?? ClientType.individual;
    _selectedClientStatus = existing?.status ?? ClientStatus.active;
    _selectedContactMethod =
        existing?.preferredContactMethod ?? ClientContactMethod.phone;
    _emailController = TextEditingController(text: existing?.email ?? '');
    _internationalPhone = existing?.phone ?? '';
    _addressLine1Controller = TextEditingController(
      text: existing?.addressLine1 ?? '',
    );
    _cityController = TextEditingController(text: existing?.city ?? '');
    _selectedStateProvince = existing?.state;
    _zipCodeController = TextEditingController(text: existing?.zipCode ?? '');
    _contactPersonController = TextEditingController(
      text: existing?.contactPerson ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _contactPersonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final l10n = context.l10n;
    final phoneInitial = widget.existing?.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.clientFormEditTitle : l10n.clientFormAddTitle,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = AdaptiveBreakpoints.sizeClassForWidth(
            constraints.maxWidth,
          );
          final formWidth = switch (sizeClass) {
            AdaptiveSizeClass.compact => constraints.maxWidth,
            AdaptiveSizeClass.medium => 640.0,
            AdaptiveSizeClass.expanded => 720.0,
          };
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: formWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.clientNameLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientType>(
                      initialValue: _selectedClientType,
                      items: ClientType.values
                          .map(
                            (type) => DropdownMenuItem<ClientType>(
                              value: type,
                              child: Text(_clientTypeLabel(type, l10n)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedClientType = value);
                      },
                      decoration: InputDecoration(
                        labelText: l10n.clientTypeLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientStatus>(
                      initialValue: _selectedClientStatus,
                      items: ClientStatus.values
                          .map(
                            (status) => DropdownMenuItem<ClientStatus>(
                              value: status,
                              child: Text(_clientStatusLabel(status, l10n)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedClientStatus = value);
                      },
                      decoration: InputDecoration(labelText: l10n.statusLabel),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientContactMethod>(
                      initialValue: _selectedContactMethod,
                      items: ClientContactMethod.values
                          .map(
                            (method) => DropdownMenuItem<ClientContactMethod>(
                              value: method,
                              child: Text(_contactMethodLabel(method, l10n)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedContactMethod = value);
                      },
                      decoration: InputDecoration(
                        labelText: l10n.preferredContactMethodLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactPersonController,
                      decoration: InputDecoration(
                        labelText: l10n.personOfContactLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.profileEmailLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppInternationalPhoneField(
                      key: ValueKey(
                        '${widget.existing?.id ?? 'new'}_${phoneInitial ?? ''}',
                      ),
                      initialPhone: phoneInitial,
                      decoration: InputDecoration(
                        labelText: l10n.profilePhoneLabel,
                      ),
                      onChanged: (value) =>
                          setState(() => _internationalPhone = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressLine1Controller,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: l10n.addressLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(labelText: l10n.cityLabel),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStateProvince,
                      items: romanianCountyCodes.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text('${entry.key} (${entry.value})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedStateProvince = value);
                      },
                      decoration: InputDecoration(labelText: l10n.countyLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _zipCodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.zipCodeLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: l10n.notesLabel),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                context.go(ForemanShellPage.clientsPath),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              isEdit ? l10n.saveChanges : l10n.createClient,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final contactPerson = _contactPersonController.text.trim();
    final email = _emailController.text.trim();
    final phone = _internationalPhone.trim();
    final addressLine1 = _addressLine1Controller.text.trim();
    final city = _cityController.text.trim();
    final state = _selectedStateProvince?.trim() ?? '';
    final zipCode = _zipCodeController.text.trim();
    final notes = _notesController.text.trim();
    if (name.isEmpty ||
        contactPerson.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        addressLine1.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        zipCode.isEmpty) {
      return;
    }

    final existing = widget.existing;
    final notifier = ref.read(clientsProvider.notifier);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (existing != null) {
        await notifier.updateClient(
          id: existing.id,
          name: name,
          activeProjects: existing.activeProjects,
          type: _selectedClientType,
          status: _selectedClientStatus,
          preferredContactMethod: _selectedContactMethod,
          notes: notes,
          contactPerson: contactPerson,
          email: email,
          phone: phone,
          addressLine1: addressLine1,
          city: city,
          stateProvince: state,
          zipCode: zipCode,
        );
      } else {
        await notifier.addClient(
          name: name,
          activeProjects: 0,
          type: _selectedClientType,
          status: _selectedClientStatus,
          preferredContactMethod: _selectedContactMethod,
          notes: notes,
          contactPerson: contactPerson,
          email: email,
          phone: phone,
          addressLine1: addressLine1,
          city: city,
          stateProvince: state,
          zipCode: zipCode,
        );
      }
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
}
