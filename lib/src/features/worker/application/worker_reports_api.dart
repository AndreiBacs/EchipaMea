import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';

class WorkerReportsApi {
  WorkerReportsApi(this._api);

  final ApiClient _api;

  /// Uploads an end-of-day report as the signed-in worker.
  ///
  /// The server takes the submitting employee from the token, not from
  /// `employeeId` in the body. The field is still sent because the wire format
  /// is shared with older builds, but it is not what decides whose work this
  /// was. A successful upload also moves the phase to pendingReview and tells
  /// the foremen; the app does neither itself.
  ///
  /// In demo mode there is no server to send to, so this succeeds without
  /// doing anything.
  Future<void> submitReport({
    required String projectId,
    required String projectName,
    required String phaseId,
    required String phaseName,
    required String employeeId,
    required String employeeName,
    required String description,
    required DateTime submittedAt,
    required List<XFile> photos,
    String? memoPath,
  }) async {
    if (!AppEnv.hasBackend) return;

    // WORKER_REPORTS_API_URL predates the shared base URL and still overrides
    // it, so an existing deployment's .env keeps working.
    final override = AppEnv.workerReportsApiUrl.trim();
    await _api.postMultipart(
      override.isNotEmpty ? override : '/worker/reports',
      fields: {
        'projectId': projectId,
        'projectName': projectName,
        'phaseId': phaseId,
        'phaseName': phaseName,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'description': description,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
        for (var i = 0; i < photos.length; i++)
          'photoNames[$i]': photos[i].name,
      },
      files: () async => [
        // Bytes rather than fromPath: on web an XFile path is a blob URL that
        // dart:io cannot open.
        for (final photo in photos)
          http.MultipartFile.fromBytes(
            'photos[]',
            await photo.readAsBytes(),
            filename: photo.name,
          ),
        if (memoPath != null && memoPath.trim().isNotEmpty)
          await http.MultipartFile.fromPath('voiceMemo', memoPath),
      ],
      // Photos from a phone on a building site: give a slow uplink room.
      timeout: const Duration(seconds: 90),
    );
  }
}
