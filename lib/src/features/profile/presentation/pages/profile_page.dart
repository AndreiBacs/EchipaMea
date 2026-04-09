import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../core/profile/profile_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/foreman/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _jobTitleController;
  final _formKey = GlobalKey<FormState>();
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _jobTitleController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLocale = ref.watch(localeProvider);
    final authSession = ref.watch(authSessionProvider).asData?.value;
    final profileState = ref.watch(profileProvider);
    final isSaving = profileState.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (profile) {
          if (!_didPrefill) {
            _fullNameController.text = profile.fullName;
            _phoneController.text = profile.phone;
            _jobTitleController.text = profile.jobTitle;
            _didPrefill = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileLanguageSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Locale?>(
                    key: ValueKey(selectedLocale?.languageCode ?? 'system'),
                    initialValue: selectedLocale,
                    items: [
                      DropdownMenuItem<Locale?>(
                        value: const Locale('en'),
                        child: Text('${l10n.english} (EN)'),
                      ),
                      DropdownMenuItem<Locale?>(
                        value: const Locale('ro'),
                        child: Text('${l10n.romanian} (RO)'),
                      ),
                      DropdownMenuItem<Locale?>(
                        value: const Locale('hu'),
                        child: Text('${l10n.hungarian} (HU)'),
                      ),
                    ],
                    onChanged: (locale) =>
                        ref.read(localeProvider.notifier).setLocale(locale),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.profilePersonalDataSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: authSession?.email ?? '',
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.profileEmailLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: l10n.profileFullNameLabel,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return l10n.profileRequiredField;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.profilePhoneLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _jobTitleController,
                    decoration: InputDecoration(
                      labelText: l10n.profileJobTitleLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isSaving ? null : _saveProfile,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.profileSaveButton),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(authSessionProvider.notifier)
                            .logout();
                        if (!context.mounted) return;
                        context.go(LoginPage.routePath);
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.logout),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await ref
        .read(profileProvider.notifier)
        .save(
          fullName: _fullNameController.text,
          phone: _phoneController.text,
          jobTitle: _jobTitleController.text,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
  }
}
