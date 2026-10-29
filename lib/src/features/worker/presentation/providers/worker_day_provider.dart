import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/config/app_env.dart';
import '../../../foreman/domain/entities/daily_worker_sequence.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../../data/worker_repository.dart';
export '../../../foreman/domain/entities/daily_worker_sequence.dart';

/// The signed-in worker's phase order on every project for one day, keyed by
/// `YYYY-MM-DD`.
final workerDayProvider = FutureProvider.autoDispose
    .family<DaySequences, String>((ref, dayKey) async {
      final repository = ref.watch(workerRepositoryProvider);
      // In mock mode suggestions come from the foreman's demo phases.
      final demoProjects = AppEnv.hasBackend
          ? null
          : ref.watch(projectsProvider.selectAsync((projects) => projects));
      final session = await watchWorkerSession(ref);
      await demoProjects;
      if (session == null) return DaySequences(dayKey: dayKey);
      return repository.day(session, dayKey);
    });
