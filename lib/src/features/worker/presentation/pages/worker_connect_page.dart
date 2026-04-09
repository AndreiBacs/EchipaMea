import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'worker_shell_page.dart';

class WorkerConnectPage extends ConsumerStatefulWidget {
  const WorkerConnectPage({super.key});

  static const routePath = '/worker/connect';
  static const routeName = 'worker_connect';

  @override
  ConsumerState<WorkerConnectPage> createState() => _WorkerConnectPageState();
}

class _WorkerConnectPageState extends ConsumerState<WorkerConnectPage> {
  bool _handled = false;
  bool _invalidScanShown = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(LoginPage.routePath);
          },
        ),
        title: Text(l10n.workerLoginTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.workerScanHint),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: (capture) {
                    if (_handled) return;
                    var ok = false;
                    var hadCandidate = false;
                    for (final barcode in capture.barcodes) {
                      final rawValue = barcode.rawValue;
                      if (rawValue == null || rawValue.isEmpty) continue;
                      hadCandidate = true;
                      ok = ref
                          .read(sessionProvider.notifier)
                          .connectFromQrPayload(rawValue);
                      if (ok) break;
                    }
                    if (!ok) {
                      if (hadCandidate && !_invalidScanShown) {
                        _invalidScanShown = true;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.workerInvalidQr),
                          ),
                        );
                        Future<void>.delayed(const Duration(seconds: 2), () {
                          if (!mounted) return;
                          _invalidScanShown = false;
                        });
                      }
                      return;
                    }
                    setState(() => _handled = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.workerConnected)),
                    );
                    if (!context.mounted) return;
                    // Defer navigation so session + GoRouter (ref.watch) settle
                    // before redirect runs.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      context.go(WorkerShellPage.workPath);
                    });
                  },
                  onDetectError: (error, stackTrace) {
                    if (_invalidScanShown || _handled) return;
                    _invalidScanShown = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.workerQrReadError),
                      ),
                    );
                    Future<void>.delayed(const Duration(seconds: 2), () {
                      if (!mounted) return;
                      _invalidScanShown = false;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (session != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: Text('${l10n.workerConnectedAs} ${session.employeeName}'),
                  subtitle: Text('${l10n.employeeIdLabel}: ${session.employeeId}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
