import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:convert';

import '../../../../core/config/app_env.dart';
import 'employee_form_page.dart';
import '../providers/team_controller.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(teamProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            runSpacing: 8,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isTablet ? 400 : MediaQuery.sizeOf(context).width - 64,
                child: Text(
                  'Employees (${employees.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push(EmployeeFormPage.createPath),
                icon: const Icon(Icons.add),
                label: const Text('Add employee'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAppDownloadQrDialog(context),
                icon: const Icon(Icons.qr_code),
                label: const Text('App download QR'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 8,
              vertical: 8,
            ),
            itemCount: employees.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                leading: CircleAvatar(child: Text(employee.initials)),
                title: Text(employee.name),
                subtitle: Text(employee.role),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_2),
                      tooltip: 'Generate login QR',
                      onPressed: () => _showEmployeeQrDialog(context, employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit employee',
                      onPressed: () =>
                          context.push('/foreman/team/${employee.id}/edit'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
          title: const Text('Employee login QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                employee.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              QrImageView(data: payload, size: 220),
              const SizedBox(height: 8),
              const Text(
                'Worker scans this code to connect automatically.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
        const SnackBar(
          content: Text(
            'APP_LANDING_URL or APP_DOWNLOAD_URL must be set in .env.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('App download QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              QrImageView(data: qrTargetUrl, size: 220),
              const SizedBox(height: 12),
              Text(
                landingUrl.isNotEmpty || iosTestflightUrl.isNotEmpty
                    ? 'Employees can scan this one link. It can route iOS to TestFlight and Android to APK.'
                    : 'Employees can scan with their phone camera to start the app download.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                qrTargetUrl,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (landingUrl.isNotEmpty &&
                  (androidDownloadUrl.isNotEmpty || iosTestflightUrl.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    [
                      if (androidDownloadUrl.isNotEmpty)
                        'Android target is set.',
                      if (iosTestflightUrl.isNotEmpty) 'iOS target is set.',
                    ].join(' '),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: qrTargetUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download link copied.')),
                );
              },
              child: const Text('Copy link'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
