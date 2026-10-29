import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_env.dart';

class WorkerReportsApi {
  /// Uploads an end-of-day report.
  ///
  /// [accessToken] is the worker's session token and is required: the server no
  /// longer accepts unauthenticated uploads, and it takes the submitting
  /// employee from the token rather than from `employeeId` in the body. The
  /// field is still sent because the wire format is shared with older builds,
  /// but it is not what decides whose work this was.
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
    required String accessToken,
    String? memoPath,
  }) async {
    final endpoint = AppEnv.workerReportsApiUrl.trim();
    if (endpoint.isEmpty) {
      throw Exception('WORKER_REPORTS_API_URL is not configured.');
    }
    if (accessToken.isEmpty) {
      throw Exception('A worker session is required to submit a report.');
    }

    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['projectId'] = projectId;
    request.fields['projectName'] = projectName;
    request.fields['phaseId'] = phaseId;
    request.fields['phaseName'] = phaseName;
    request.fields['employeeId'] = employeeId;
    request.fields['employeeName'] = employeeName;
    request.fields['description'] = description;
    request.fields['submittedAt'] = submittedAt.toUtc().toIso8601String();

    for (var i = 0; i < photos.length; i++) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'photos[]',
          photos[i].path,
          filename: photos[i].name,
        ),
      );
      request.fields['photoNames[$i]'] = photos[i].name;
    }

    if (memoPath != null && memoPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('voiceMemo', memoPath),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final responseBody = await streamed.stream.bytesToString();
      throw Exception(
        'Failed to submit report (${streamed.statusCode}): '
        '${responseBody.isEmpty ? 'no response body' : responseBody}',
      );
    }

    // Read body to fully complete and release stream resources.
    await streamed.stream.drain<List<int>>();

    // The foreman notification is the server's job now.
    //
    // This used to open a one-shot websocket and publish a
    // `worker_report_submitted` frame after the upload. Three reasons it is
    // gone:
    //
    //  - It was unreliable in exactly the case it mattered. On a slow site
    //    connection the 30s timeout above throws before this line runs, so the
    //    report existed on the server with nobody told about it.
    //  - The server now fans out on a successful upload, so the frame was
    //    redundant; it resolved to the same idempotency key and did nothing.
    //  - It was the only writer on the foreman notification channel. With it
    //    gone that channel has readers only, so the server can require a
    //    foreman ticket there instead of admitting anonymous connections --
    //    which is what stopped anyone who could reach the port from reading a
    //    company's report events.
  }
}
