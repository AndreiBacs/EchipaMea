import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_controller.dart';
import '../../../../core/setup/setup_flow_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../legal/presentation/pages/terms_page.dart';

class SetupFlowPage extends ConsumerStatefulWidget {
  const SetupFlowPage({super.key});

  static const routePath = '/setup';
  static const routeName = 'setup';

  @override
  ConsumerState<SetupFlowPage> createState() => _SetupFlowPageState();
}

class _SetupFlowPageState extends ConsumerState<SetupFlowPage> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(setupFlowCompletedProvider.notifier).complete();
    if (!mounted) return;
    context.go(LoginPage.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedLocale = ref.watch(localeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupFlowTitle),
        actions: [
          TextButton(
            onPressed: () => context.push(TermsPage.routePath),
            child: Text(l10n.termsAndConditions),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) {
                final selected = i == _pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: selected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                _WelcomeStep(l10n: l10n),
                _LanguageStep(
                  l10n: l10n,
                  selectedLocale: selectedLocale,
                  onLocaleChanged: (locale) =>
                      ref.read(localeProvider.notifier).setLocale(locale),
                ),
                _RolesStep(l10n: l10n),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                if (_pageIndex > 0)
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Text(l10n.setupBack),
                  )
                else
                  const SizedBox(width: 8),
                const Spacer(),
                if (_pageIndex < _pageCount - 1)
                  FilledButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Text(l10n.setupNext),
                  )
                else
                  FilledButton(
                    onPressed: _finish,
                    child: Text(l10n.setupGetStarted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.setupWelcomeHeadline,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(l10n.setupWelcomeBody, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.l10n,
    required this.selectedLocale,
    required this.onLocaleChanged,
  });

  final AppLocalizations l10n;
  final Locale? selectedLocale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.language,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.setupLanguageHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<Locale?>(
            key: ValueKey(selectedLocale?.languageCode ?? 'system'),
            initialValue: selectedLocale,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.language,
            ),
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
            onChanged: onLocaleChanged,
          ),
        ],
      ),
    );
  }
}

class _RolesStep extends StatelessWidget {
  const _RolesStep({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.setupRolesHeadline,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.setupRolesIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          _RoleCard(
            title: l10n.foreman,
            body: l10n.roleForemanDescription,
            icon: Icons.engineering_outlined,
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: l10n.worker,
            body: l10n.roleWorkerDescription,
            icon: Icons.construction_outlined,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
