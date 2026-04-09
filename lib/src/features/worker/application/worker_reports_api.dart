import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_env.dart';

class WorkerReportsApi {
  Future<void> submitReport({
    required String projectId,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String description,
    required DateTime submittedAt,
    required List<XFile> photos,
    String? memoPath,
  }) async {
    final endpoint = AppEnv.workerReportsApiUrl.trim();
    if (endpoint.isEmpty) {
      throw Exception('WORKER_REPORTS_API_URL is not configured.');
    }

    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);
    request.fields['projectId'] = projectId;
    request.fields['projectName'] = projectName;
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
        await http.MultipartFile.fromPath(
          'voiceMemo',
          memoPath,
        ),
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

    // Best-effort one-shot websocket ping so the backend can fan out to foremen.
    // Delivery is not guaranteed; the HTTP upload above is the source of truth.
    await _notifyForemanReportSubmitted(
      projectId: projectId,
      projectName: projectName,
      employeeId: employeeId,
      employeeName: employeeName,
      description: description,
      submittedAt: submittedAt,
      photoCount: photos.length,
      hasVoiceMemo: memoPath != null && memoPath.trim().isNotEmpty,
    );
  }

  Future<void> _notifyForemanReportSubmitted({
    required String projectId,
    required String projectName,
    required String employeeId,
    required String employeeName,
    required String description,
    required DateTime submittedAt,
    required int photoCount,
    required bool hasVoiceMemo,
  }) async {
    final wsEndpoint = AppEnv.foremanNotificationsWsUrl.trim();
    if (wsEndpoint.isEmpty) return;

    final uri = Uri.tryParse(wsEndpoint);
    if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss')) return;

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(uri);
      await channel.ready;
      final payload = {
        'type': 'worker_report_submitted',
        'projectId': projectId,
        'projectName': projectName,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'description': description,
        'photoCount': photoCount,
        'hasVoiceMemo': hasVoiceMemo,
        'submittedAt': submittedAt.toUtc().toIso8601String(),
      };
      channel.sink.add(jsonEncode(payload));
    } catch (_) {
      // Non-blocking: report upload already succeeded.
    } finally {
      // Await close so the sink drains before we drop the channel.
      await channel?.sink.close();
    }
  }
}

