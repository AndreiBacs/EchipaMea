import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import '../../../../core/ui/async_status_view.dart';
import '../../application/foreman_notifications_coordinator.dart';
import '../../domain/entities/foreman_notification.dart';
import 'clients_page.dart';
import 'dashboard_page.dart';
import 'project_form_page.dart';
import 'projects_page.dart';
import 'team_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

enum ForemanTab { dashboard, projects, clients, team, profile }

class ForemanShellPage extends ConsumerWidget {
  const ForemanShellPage({super.key, required this.currentTab});

  static const dashboardPath = '/foreman/dashboard';
  static const projectsPath = '/foreman/projects';
  static const clientsPath = '/foreman/clients';
  static const teamPath = '/foreman/team';
  static const profilePath = '/foreman/profile';

  final ForemanTab currentTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unreadCount =
        ref.watch(foremanNotificationsProvider).current?.unreadCount ?? 0;
    final body = switch (currentTab) {
      ForemanTab.dashboard => const DashboardPage(),
      ForemanTab.projects => const ProjectsPage(),
      ForemanTab.clients => const ClientsPage(),
      ForemanTab.team => const TeamPage(),
      ForemanTab.profile => const ProfilePage(),
    };
    final sizeClass = AdaptiveBreakpoints.fromContext(context);
    final useBottomNav = sizeClass == AdaptiveSizeClass.compact;
    final useRail = sizeClass == AdaptiveSizeClass.medium;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.foremanShellTitle),
        actions: [
          IconButton(
            tooltip: l10n.foremanNotifications,
            onPressed: () => _showNotificationsDialog(context, ref),
            icon: Badge.count(
              count: unreadCount,
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authSessionProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: useBottomNav
          ? body
          : Row(
              children: [
                if (useRail)
                  NavigationRail(
                    selectedIndex: currentTab.index,
                    onDestinationSelected: (index) =>
                        _onTabSelected(context, index),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.dashboard),
                        label: Text(l10n.dashboardTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.work),
                        label: Text(l10n.projectsTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.handshake),
                        label: Text(l10n.clientsTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.groups),
                        label: Text(l10n.teamTab),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person),
                        label: Text(l10n.profileTab),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: 280,
                    child: NavigationDrawer(
                      selectedIndex: currentTab.index,
                      onDestinationSelected: (index) =>
                          _onTabSelected(context, index),
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
                          icon: const Icon(Icons.dashboard),
                          label: Text(l10n.dashboardTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.work),
                          label: Text(l10n.projectsTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.handshake),
                          label: Text(l10n.clientsTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.groups),
                          label: Text(l10n.teamTab),
                        ),
                        NavigationDrawerDestination(
                          icon: const Icon(Icons.person),
                          label: Text(l10n.profileTab),
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
              onDestinationSelected: (index) => _onTabSelected(context, index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard),
                  label: l10n.dashboardTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.work),
                  label: l10n.projectsTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.handshake),
                  label: l10n.clientsTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.groups),
                  label: l10n.teamTab,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: l10n.profileTab,
                ),
              ],
            )
          : null,
    );
  }

  void _onTabSelected(BuildContext context, int index) {
    final tab = ForemanTab.values[index];
    final path = switch (tab) {
      ForemanTab.dashboard => dashboardPath,
      ForemanTab.projects => projectsPath,
      ForemanTab.clients => clientsPath,
      ForemanTab.team => teamPath,
      ForemanTab.profile => profilePath,
    };
    context.go(path);
  }

  Future<void> _showNotificationsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final router = GoRouter.of(context);
    unawaited(ref.read(foremanNotificationsProvider.notifier).markAllRead());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, _) {
          // Worded here, in the current language, so switching language
          // rewords the list too.
          final l10n = context.l10n;
          final items =
              ref.watch(foremanNotificationsProvider).current?.items ??
              const <ForemanNotificationItem>[];
          return AlertDialog(
            title: Text(l10n.foremanNotifications),
            content: SizedBox(
              width: 420,
              child: items.isEmpty
                  ? Text(l10n.foremanNotificationsEmpty)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final hh = item.occurredAt.hour.toString().padLeft(
                          2,
                          '0',
                        );
                        final mm = item.occurredAt.minute.toString().padLeft(
                          2,
                          '0',
                        );
                        final projectId = item.projectId;
                        return ListTile(
                          dense: true,
                          title: Text(_notificationTitle(l10n, item)),
                          subtitle: Text(
                            '${_notificationText(l10n, item)}\n$hh:$mm',
                          ),
                          isThreeLine: true,
                          onTap: projectId == null
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop();
                                  router.push(
                                    ProjectFormPage.editPathWithPhasesTab(
                                      projectId,
                                    ),
                                  );
                                },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _notificationTitle(
    AppLocalizations l10n,
    ForemanNotificationItem item,
  ) => switch (item.kind) {
    ForemanNotificationKind.workerReportSubmitted =>
      l10n.foremanNotificationWorkerReportTitle,
    ForemanNotificationKind.phaseApproved =>
      l10n.foremanNotificationPhaseApprovedTitle,
    ForemanNotificationKind.phaseRejected =>
      l10n.foremanNotificationPhaseRejectedTitle,
    ForemanNotificationKind.workerArrived =>
      l10n.foremanNotificationWorkerArrivedTitle,
    ForemanNotificationKind.other => l10n.foremanNotificationOtherTitle,
  };

  /// Who and where, from the names recorded when it happened.
  static String _notificationText(
    AppLocalizations l10n,
    ForemanNotificationItem item,
  ) {
    final parts = [
      item.employeeName,
      item.projectName,
      item.phaseName,
    ].where((part) => part.trim().isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' - ');
    return item.kind == ForemanNotificationKind.workerReportSubmitted
        ? l10n.foremanNotificationWorkerReportBodyFallback
        : '';
  }
}
