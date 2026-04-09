import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'worker_reports_api.dart';

final workerReportsApiProvider = Provider<WorkerReportsApi>(
  (ref) => WorkerReportsApi(),
);
