import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import 'worker_reports_api.dart';

final workerReportsApiProvider = Provider<WorkerReportsApi>(
  (ref) => WorkerReportsApi(ref.watch(workerApiProvider)),
);
