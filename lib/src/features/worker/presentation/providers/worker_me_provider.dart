import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/config/app_env.dart';
import '../../../foreman/presentation/providers/team_controller.dart';
import '../../data/worker_repository.dart';

/// The signed-in worker's own record, with the working schedule that gates
/// location telemetry. Null while no worker is signed in.
final workerMeProvider = FutureProvider<Employee?>((ref) async {
  final repository = ref.watch(workerRepositoryProvider);
  // In mock mode the record comes from the foreman's demo roster, so a
  // schedule edited there applies here at once.
  final demoTeam = AppEnv.hasBackend
      ? null
      : ref.watch(teamProvider.selectAsync((team) => team));
  final session = await watchWorkerSession(ref);
  await demoTeam;
  if (session == null) return null;
  return repository.me(session);
});
