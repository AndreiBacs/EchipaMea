import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routePath = '/';
  static const routeName = 'home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('EchipaMea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flutter starter is ready',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Stitch MCP URL: ${vm.stitchMcpUrl}'),
            const SizedBox(height: 8),
            Text(
              vm.hasStitchApiKey
                  ? 'Stitch API key is configured.'
                  : 'Stitch API key missing. Set STITCH_API_KEY in .env',
            ),
          ],
        ),
      ),
    );
  }
}
