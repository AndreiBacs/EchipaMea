import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/app_user_role.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../foreman/presentation/pages/foreman_shell_page.dart';
import '../../../legal/presentation/pages/terms_page.dart';
import '../../../worker/presentation/pages/worker_connect_page.dart';
import '../providers/home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routePath = '/';
  static const routeName = 'home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(homeControllerProvider);
    final selectedRole = ref.watch(selectedRoleProvider);
    final selectedLocale = ref.watch(localeProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeTagline,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.language,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Locale?>(
              key: ValueKey(selectedLocale?.languageCode ?? 'system'),
              initialValue: selectedLocale,
              items: [
                DropdownMenuItem<Locale?>(
                  value: null,
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
            const SizedBox(height: 12),
            Text(
              l10n.selectRole,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppUserRole.values.map((role) {
                return ChoiceChip(
                  label: Text(
                    role == AppUserRole.foreman ? l10n.foreman : l10n.worker,
                  ),
                  selected: selectedRole == role,
                  onSelected: (_) =>
                      ref.read(selectedRoleProvider.notifier).setRole(role),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              vm.selectedRole == AppUserRole.foreman
                  ? l10n.roleForemanDescription
                  : l10n.roleWorkerDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                if (selectedRole == AppUserRole.foreman) {
                  context.go(ForemanShellPage.dashboardPath);
                  return;
                }
                context.go(WorkerConnectPage.routePath);
              },
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.continueLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(TermsPage.routePath),
              child: Text(l10n.termsAndConditions),
            ),
          ],
        ),
      ),
    );
  }
}
