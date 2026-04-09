import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';

class WorkerProfilePage extends ConsumerWidget {
  const WorkerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(sessionProvider);
    final selectedLocale = ref.watch(localeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (session != null) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  session.employeeName.isNotEmpty
                      ? session.employeeName.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
              title: Text(session.employeeName),
              subtitle: Text('${l10n.employeeIdLabel}: ${session.employeeId}'),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(sessionProvider.notifier).disconnect();
              context.go(LoginPage.routePath);
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
        ),
      ],
    );
  }
}
