import 'dart:convert';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/network/realtime_ticket_api.dart';
import '../domain/entities/foreman_notification.dart';
import '../presentation/providers/projects_controller.dart';

final foremanNotificationsProvider =
    NotifierProvider<ForemanNotificationsNotifier, ForemanNotificationsState>(
      ForemanNotificationsNotifier.new,
    );

class ForemanNotificationsNotifier extends Notifier<ForemanNotificationsState> {
  WebSocketChannel? _channel;
  bool _connecting = false;
  final RealtimeTicketApi _tickets = RealtimeTicketApi();

  @override
  ForemanNotificationsState build() {
    ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (_, next) {
      final session = next.asData?.value;
      if (session == null) {
        _disconnect();
        state = const ForemanNotificationsState.empty();
        return;
      }
      unawaited(_connect(session));
    }, fireImmediately: true);
    ref.onDispose(_disconnect);
    return const ForemanNotificationsState.empty();
  }

  void markAllRead() {
    state = state.copyWith(unreadCount: 0);
  }

  /// Opens the feed, proving who we are first.
  ///
  /// This channel used to be opened with no credentials at all, which meant the
  /// server had to admit anonymous readers to make it work -- and an anonymous
  /// reader on a company's report feed is a stranger reading it. A ticket is
  /// fetched with the stored foreman token and passed as `?ticket=`, because
  /// Dart cannot set headers on a WebSocket from Flutter web.
  ///
  /// Without a ticket we simply do not connect. Failing closed costs a
  /// notification badge; failing open costs the company's data.
  Future<void> _connect(AuthSession session) async {
    if (_channel != null || _connecting) return;
    final endpoint = AppEnv.foremanNotificationsWsUrl.trim();
    if (endpoint.isEmpty) return;

    _connecting = true;
    try {
      final ticket = await _tickets.fetchTicket(accessToken: session.token);
      if (ticket == null) return;

      // The session may have ended while the ticket request was in flight.
      if (ref.read(authSessionProvider).asData?.value == null) return;

      final uri = socketUriWithTicket(endpoint, ticket);
      if (uri == null) return;

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.stream.listen(
        _onMessage,
        onError: (_) => _disconnect(),
        onDone: _disconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _disconnect();
    } finally {
      _connecting = false;
    }
  }

  void _disconnect() {
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close() ?? Future<void>.value());
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic>? data;
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      }
    } catch (_) {
      data = null;
    }
    if (data == null) return;

    if (data['type'] != 'worker_report_submitted') return;

    final projectId = (data['projectId'] as String?)?.trim();
    final phaseId = (data['phaseId'] as String?)?.trim();
    if (projectId != null && projectId.isNotEmpty) {
      final projects = ref.read(projectsProvider);
      Project? targetProject;
      for (final p in projects) {
        if (p.id == projectId) {
          targetProject = p;
          break;
        }
      }
      if (targetProject != null) {
        String? targetPhaseId = phaseId;
        if (targetPhaseId == null || targetPhaseId.isEmpty) {
          for (final phase in targetProject.phases) {
            if (phase.status == PhaseStatus.notStarted ||
                phase.status == PhaseStatus.inProgress) {
              targetPhaseId = phase.id;
              break;
            }
          }
        }
        if (targetPhaseId != null && targetPhaseId.isNotEmpty) {
          final employeeId = (data['employeeId'] as String?)?.trim() ?? '';
          ref
              .read(projectsProvider.notifier)
              .submitPhaseForReview(
                projectId: projectId,
                phaseId: targetPhaseId,
                employeeId: employeeId,
              );
        }
      }
    }

    final employeeName = (data['employeeName'] as String?)?.trim();
    final projectName = (data['projectName'] as String?)?.trim();
    final submittedAtRaw = data['submittedAt'] as String?;
    final submittedAt =
        DateTime.tryParse(submittedAtRaw ?? '') ?? DateTime.now();

    final locale = ref.read(localeProvider) ?? const Locale('ro');
    final l10n = AppLocalizations(locale);
    final title = l10n.foremanNotificationWorkerReportTitle;
    final subtitle = [
      if (employeeName != null && employeeName.isNotEmpty) employeeName,
      if (projectName != null && projectName.isNotEmpty) projectName,
    ].join(' - ');

    final item = ForemanNotificationItem(
      title: title,
      subtitle: subtitle.isEmpty
          ? l10n.foremanNotificationWorkerReportBodyFallback
          : subtitle,
      receivedAt: submittedAt.toLocal(),
    );

    final nextItems = [item, ...state.items];
    state = state.copyWith(
      items: nextItems.take(50).toList(),
      unreadCount: state.unreadCount + 1,
    );
  }
}
