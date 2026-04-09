import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import '../../../../core/ui/app_international_phone_field.dart';
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
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactPersonController;
  String _internationalPhone = '';

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
    _emailController = TextEditingController(text: existing?.email ?? '');
    _internationalPhone = existing?.phone ?? '';
    _addressController = TextEditingController(text: existing?.address ?? '');
    _contactPersonController = TextEditingController(
      text: existing?.contactPerson ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _activeProjectsController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.clientId != null;
    final l10n = context.l10n;
    final phoneInitial = widget.clientId == null
        ? null
        : ref.read(clientsProvider.notifier).findById(widget.clientId!)?.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.clientFormEditTitle : l10n.clientFormAddTitle),
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
                      decoration: InputDecoration(labelText: l10n.clientNameLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _activeProjectsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.activeProjectsLabel,
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
                        '${widget.clientId ?? 'new'}_${phoneInitial ?? ''}',
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
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: l10n.addressLabel),
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
                            onPressed: () => _save(context, isEdit: isEdit),
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

  void _save(BuildContext context, {required bool isEdit}) {
    final name = _nameController.text.trim();
    final activeProjects = int.tryParse(_activeProjectsController.text.trim());
    final contactPerson = _contactPersonController.text.trim();
    final email = _emailController.text.trim();
    final phone = _internationalPhone.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty ||
        activeProjects == null ||
        activeProjects < 0 ||
        contactPerson.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty) {
      return;
    }

    if (isEdit) {
      ref
          .read(clientsProvider.notifier)
          .updateClient(
            id: widget.clientId!,
            name: name,
            activeProjects: activeProjects,
            contactPerson: contactPerson,
            email: email,
            phone: phone,
            address: address,
          );
    } else {
      ref
          .read(clientsProvider.notifier)
          .addClient(
            name: name,
            activeProjects: activeProjects,
            contactPerson: contactPerson,
            email: email,
            phone: phone,
            address: address,
          );
    }

    Navigator.of(context).pop();
  }
}
