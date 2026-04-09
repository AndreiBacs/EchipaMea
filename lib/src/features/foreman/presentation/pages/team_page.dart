import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:convert';

import '../../../../core/config/app_env.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'employee_form_page.dart';
import '../providers/team_controller.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(teamProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;
    final l10n = context.l10n;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Wrap(
                runSpacing: 8,
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isTablet
                        ? 400
                        : MediaQuery.sizeOf(context).width - 64,
                    child: Text(
                      '${l10n.employeesTitle} (${employees.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showAppDownloadQrDialog(context),
                    icon: const Icon(Icons.qr_code),
                    label: Text(l10n.appDownloadQr),
                  ),
                ],
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
                itemCount: employees.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return Dismissible(
                    key: ValueKey('employee_${employee.id}'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        await _showEmployeeQrDialog(context, employee);
                      } else {
                        context.push('/foreman/team/${employee.id}/edit');
                      }
                      return false;
                    },
                    background: _SwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      icon: Icons.edit_outlined,
                      label: l10n.quickEdit,
                    ),
                    secondaryBackground: _SwipeActionBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.qr_code_2,
                      label: l10n.quickQr,
                    ),
                    child: Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(child: Text(employee.initials)),
                        title: Text(
                          employee.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  Text(employee.role),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${employee.email} • ${employee.phone}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.workingScheduleLabel}: ${_scheduleLabel(l10n, employee)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_2),
                              tooltip: l10n.generateLoginQrTooltip,
                              onPressed: () =>
                                  _showEmployeeQrDialog(context, employee),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.editEmployeeTooltip,
                              onPressed: () =>
                                  context.push('/foreman/team/${employee.id}/edit'),
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
            onPressed: () => context.push(EmployeeFormPage.createPath),
            icon: const Icon(Icons.add),
            label: Text(l10n.addEmployee),
          ),
        ),
      ],
    );
  }

  String _scheduleLabel(AppLocalizations l10n, Employee employee) {
    final orderedDays = employee.workingDays.toList()..sort();
    final dayLabels = orderedDays.map((day) {
      return switch (day) {
        1 => l10n.weekdayMon,
        2 => l10n.weekdayTue,
        3 => l10n.weekdayWed,
        4 => l10n.weekdayThu,
        5 => l10n.weekdayFri,
        6 => l10n.weekdaySat,
        _ => l10n.weekdaySun,
      };
    }).join(', ');
    final start = employee.workStartHour.toString().padLeft(2, '0');
    final end = employee.workEndHour.toString().padLeft(2, '0');
    return '$dayLabels • $start:00-$end:00';
  }

  Future<void> _showEmployeeQrDialog(
    BuildContext context,
    Employee employee,
  ) async {
    final payload = jsonEncode({
      'type': 'employee_login',
      'employeeId': employee.id,
      'employeeName': employee.name,
      'issuedAt': DateTime.now().toIso8601String(),
    });

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.employeeLoginQrTitle),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  employee.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox.square(
                  dimension: 236,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: QrImageView(
                        data: payload,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        errorStateBuilder: (context, error) {
                          return SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(
                              child: Text(
                                '${context.l10n.qrRenderError}:\n$error',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.workerScansToConnect,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAppDownloadQrDialog(BuildContext context) async {
    final landingUrl = AppEnv.appLandingUrl.trim();
    final androidDownloadUrl = AppEnv.appDownloadUrl.trim();
    final iosTestflightUrl = AppEnv.appIosTestflightUrl.trim();
    final qrTargetUrl = _resolveQrTargetUrl(
      landingUrl: landingUrl,
      androidDownloadUrl: androidDownloadUrl,
      iosTestflightUrl: iosTestflightUrl,
    );

    if (qrTargetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.appDownloadMissingUrl,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.appDownloadQrTitle),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 236,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: QrImageView(
                        data: qrTargetUrl,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        errorStateBuilder: (context, error) {
                          return SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(
                              child: Text(
                                '${context.l10n.qrRenderError}:\n$error',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  landingUrl.isNotEmpty || iosTestflightUrl.isNotEmpty
                      ? context.l10n.appDownloadHintRouted
                      : context.l10n.appDownloadHintDirect,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  qrTargetUrl,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (landingUrl.isNotEmpty &&
                    (androidDownloadUrl.isNotEmpty ||
                        iosTestflightUrl.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      [
                        if (androidDownloadUrl.isNotEmpty)
                          context.l10n.androidTargetSet,
                        if (iosTestflightUrl.isNotEmpty)
                          context.l10n.iosTargetSet,
                      ].join(' '),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: qrTargetUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.downloadLinkCopied)),
                );
              },
              child: Text(context.l10n.copyLink),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
  }

  String _resolveQrTargetUrl({
    required String landingUrl,
    required String androidDownloadUrl,
    required String iosTestflightUrl,
  }) {
    if (landingUrl.isNotEmpty) {
      final base = Uri.tryParse(landingUrl);
      if (base != null && base.hasScheme && base.host.isNotEmpty) {
        final hasAndroid = base.queryParameters.containsKey('android');
        final hasIos = base.queryParameters.containsKey('ios');
        if (!hasAndroid && !hasIos) {
          final mergedQuery = <String, String>{
            ...base.queryParameters,
            if (androidDownloadUrl.isNotEmpty) 'android': androidDownloadUrl,
            if (iosTestflightUrl.isNotEmpty) 'ios': iosTestflightUrl,
          };
          return base.replace(queryParameters: mergedQuery).toString();
        }
      }
      return landingUrl;
    }

    if (androidDownloadUrl.isNotEmpty) {
      return androidDownloadUrl;
    }
    return '';
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
