import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/auth/session_controller.dart';

class WorkerConnectPage extends ConsumerStatefulWidget {
  const WorkerConnectPage({super.key});

  static const routePath = '/worker/connect';
  static const routeName = 'worker_connect';

  @override
  ConsumerState<WorkerConnectPage> createState() => _WorkerConnectPageState();
}

class _WorkerConnectPageState extends ConsumerState<WorkerConnectPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Worker Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan the QR code from foreman dashboard to connect automatically.',
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: (capture) {
                    if (_handled) return;
                    final rawValue = capture.barcodes.first.rawValue;
                    if (rawValue == null || rawValue.isEmpty) return;
                    final ok = ref
                        .read(sessionProvider.notifier)
                        .connectFromQrPayload(rawValue);
                    if (!ok) return;
                    setState(() => _handled = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connected successfully.')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (session != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: Text('Connected as ${session.employeeName}'),
                  subtitle: Text('Employee ID: ${session.employeeId}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
