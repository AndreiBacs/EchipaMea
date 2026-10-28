import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/profile/profile_controller.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/ui/app_international_phone_field.dart';
import '../../../../core/ui/async_status_view.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../foreman/presentation/pages/foreman_getting_started_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const routePath = '/foreman/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _fullNameController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyAddressLine1Controller;
  late final TextEditingController _companyCityController;
  late final TextEditingController _companyStateController;
  late final TextEditingController _companyZipCodeController;
  late final TextEditingController _companyIbanController;
  late final TextEditingController _companyCuiController;
  late final TextEditingController _companyVatController;
  late final TextEditingController _companyRegComController;
  late final TabController _profileTabController;
  final _formKey = GlobalKey<FormState>();
  bool _didPrefill = false;
  bool _saving = false;
  String _profilePhone = '';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _jobTitleController = TextEditingController();
    _companyNameController = TextEditingController();
    _companyAddressLine1Controller = TextEditingController();
    _companyCityController = TextEditingController();
    _companyStateController = TextEditingController();
    _companyZipCodeController = TextEditingController();
    _companyIbanController = TextEditingController();
    _companyCuiController = TextEditingController();
    _companyVatController = TextEditingController();
    _companyRegComController = TextEditingController();
    _profileTabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _jobTitleController.dispose();
    _companyNameController.dispose();
    _companyAddressLine1Controller.dispose();
    _companyCityController.dispose();
    _companyStateController.dispose();
    _companyZipCodeController.dispose();
    _companyIbanController.dispose();
    _companyCuiController.dispose();
    _companyVatController.dispose();
    _companyRegComController.dispose();
    _profileTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLocale = ref.watch(localeProvider);
    final selectedThemeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final authSession = ref.watch(authSessionProvider).asData?.value;
    final profileState = ref.watch(myProfileProvider);
    final companyState = ref.watch(companyProvider);
    final profile = profileState.current;
    final company = companyState.current;

    if (profile != null && company != null && !_didPrefill) {
      _fullNameController.text = profile.fullName;
      _profilePhone = profile.phone;
      _jobTitleController.text = profile.jobTitle;
      _companyNameController.text = company.name;
      _companyAddressLine1Controller.text = company.addressLine1;
      _companyCityController.text = company.city;
      _companyStateController.text = company.state;
      _companyZipCodeController.text = company.zipCode;
      _companyIbanController.text = company.iban;
      _companyCuiController.text = company.cui;
      _companyVatController.text = company.vatNumber;
      _companyRegComController.text = company.regCom;
      _didPrefill = true;
    }

    // Language, theme and logout stay usable when the profile cannot load.
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Text(
                l10n.profileThemeSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ThemeMode>(
                key: ValueKey(selectedThemeMode.name),
                initialValue: selectedThemeMode,
                items: [
                  DropdownMenuItem<ThemeMode>(
                    value: ThemeMode.system,
                    child: Text(l10n.themeModeSystem),
                  ),
                  DropdownMenuItem<ThemeMode>(
                    value: ThemeMode.light,
                    child: Text(l10n.themeModeLight),
                  ),
                  DropdownMenuItem<ThemeMode>(
                    value: ThemeMode.dark,
                    child: Text(l10n.themeModeDark),
                  ),
                ],
                onChanged: (mode) {
                  if (mode == null) return;
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome),
                title: Text(l10n.foremanGettingStartedTitle),
                subtitle: Text(l10n.foremanGettingStartedDescription),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(ForemanGettingStartedPage.path),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _profileTabController,
                tabs: [
                  Tab(text: l10n.profilePersonalTab),
                  Tab(text: l10n.profileCompanyTab),
                ],
              ),
              const SizedBox(height: 12),
              if (profile == null || company == null)
                AsyncStatusView(
                  profileState.hasError ? profileState : companyState,
                  onRetry: () {
                    ref.invalidate(myProfileProvider);
                    ref.invalidate(companyProvider);
                  },
                )
              else if (_profileTabController.index == 0) ...[
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
                AppInternationalPhoneField(
                  key: ValueKey(profile.phone),
                  initialPhone: profile.phone,
                  decoration: InputDecoration(
                    labelText: l10n.profilePhoneLabel,
                  ),
                  onChanged: (value) => setState(() => _profilePhone = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobTitleController,
                  decoration: InputDecoration(
                    labelText: l10n.profileJobTitleLabel,
                  ),
                ),
              ] else ...[
                Text(
                  l10n.profileCompanyDataSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyNameLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyAddressLine1Controller,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyAddressLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyCityController,
                  decoration: InputDecoration(labelText: l10n.cityLabel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyStateController,
                  decoration: InputDecoration(labelText: l10n.countyLabel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyZipCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.zipCodeLabel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyIbanController,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyIbanLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyCuiController,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyCuiLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyVatController,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyVatLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyRegComController,
                  decoration: InputDecoration(
                    labelText: l10n.profileCompanyRegComLabel,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: profile == null || company == null || _saving
                    ? null
                    : _saveProfile,
                icon: const Icon(Icons.save),
                label: Text(l10n.profileSaveButton),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authSessionProvider.notifier).logout();
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
      ),
    );
  }

  Future<void> _saveProfile() async {
    final profile = ref.read(myProfileProvider).current;
    final company = ref.read(companyProvider).current;
    if (profile == null || company == null) return;
    if (!_formKey.currentState!.validate()) return;

    final nextProfile = MyProfile(
      fullName: _fullNameController.text,
      phone: _profilePhone,
      jobTitle: _jobTitleController.text,
    ).trimmed();
    final nextCompany = CompanyDetails(
      name: _companyNameController.text,
      addressLine1: _companyAddressLine1Controller.text,
      city: _companyCityController.text,
      state: _companyStateController.text,
      zipCode: _companyZipCodeController.text,
      iban: _companyIbanController.text,
      cui: _companyCuiController.text,
      vatNumber: _companyVatController.text,
      regCom: _companyRegComController.text,
    ).trimmed();

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      // Only a record that changed is sent: the company is shared with the
      // other foremen, and an untouched form must not overwrite their edits.
      if (nextProfile != profile) {
        await ref.read(myProfileProvider.notifier).save(nextProfile);
      }
      if (nextCompany != company) {
        await ref.read(companyProvider.notifier).save(nextCompany);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(apiErrorMessage(l10n, error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
