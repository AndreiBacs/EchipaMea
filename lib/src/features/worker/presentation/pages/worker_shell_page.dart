import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import 'worker_home_page.dart';
import 'worker_profile_page.dart';

enum WorkerTab { work, profile }

class WorkerShellPage extends ConsumerWidget {
  const WorkerShellPage({super.key, required this.currentTab});

  static const workPath = '/worker/work';
  static const profilePath = '/worker/profile';

  final WorkerTab currentTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final body = switch (currentTab) {
      WorkerTab.work => const WorkerHomePage(),
      WorkerTab.profile => const WorkerProfilePage(),
    };
    final sizeClass = AdaptiveBreakpoints.fromContext(context);
    final useBottomNav = sizeClass == AdaptiveSizeClass.compact;
    final useRail = sizeClass == AdaptiveSizeClass.medium;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workerShellTitle),
      ),
      body: useBottomNav
          ? body
          : Row(
              children: [
                if (useRail)
                  NavigationRail(
                    selectedIndex: currentTab.index,
                    onDestinationSelected: (index) =>
                        _onTabSelected(context, WorkerTab.values[index]),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.construction),
                        label: Text(l10n.workerWorkTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person),
                        label: Text(l10n.workerProfileTab),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: 260,
                    child: NavigationDrawer(
                      selectedIndex: currentTab.index,
                      onDestinationSelected: (index) =>
                          _onTabSelected(context, WorkerTab.values[index]),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
                          child: Text(
                            l10n.navigation,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.construction),
                          label: Text(l10n.workerWorkTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.person),
                          label: Text(l10n.workerProfileTab),
                        ),
                      ],
                    ),
                  ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
      bottomNavigationBar: useBottomNav
          ? NavigationBar(
              selectedIndex: currentTab.index,
              onDestinationSelected: (index) =>
                  _onTabSelected(context, WorkerTab.values[index]),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.construction),
                  label: l10n.workerWorkTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: l10n.workerProfileTab,
                ),
              ],
            )
          : null,
    );
  }

  void _onTabSelected(BuildContext context, WorkerTab tab) {
    final path = switch (tab) {
      WorkerTab.work => workPath,
      WorkerTab.profile => profilePath,
    };
    context.go(path);
  }
}
