import 'dart:convert';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';

final foremanNotificationsProvider =
    NotifierProvider<ForemanNotificationsNotifier, ForemanNotificationsState>(
      ForemanNotificationsNotifier.new,
    );

class ForemanNotificationsNotifier extends Notifier<ForemanNotificationsState> {
  WebSocketChannel? _channel;

  @override
  ForemanNotificationsState build() {
    ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (_, next) {
      final session = next.asData?.value;
      if (session == null) {
        _disconnect();
        state = const ForemanNotificationsState.empty();
        return;
      }
      _connect();
    }, fireImmediately: true);
    ref.onDispose(_disconnect);
    return const ForemanNotificationsState.empty();
  }

  void markAllRead() {
    state = state.copyWith(unreadCount: 0);
  }

  void _connect() {
    if (_channel != null) return;
    final endpoint = AppEnv.foremanNotificationsWsUrl.trim();
    if (endpoint.isEmpty) return;
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !(uri.scheme == 'ws' || uri.scheme == 'wss')) return;

    try {
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

    final employeeName = (data['employeeName'] as String?)?.trim();
    final projectName = (data['projectName'] as String?)?.trim();
    final submittedAtRaw = data['submittedAt'] as String?;
    final submittedAt = DateTime.tryParse(submittedAtRaw ?? '') ?? DateTime.now();

    final title = 'Worker report submitted';
    final subtitle = [
      if (employeeName != null && employeeName.isNotEmpty) employeeName,
      if (projectName != null && projectName.isNotEmpty) projectName,
    ].join(' - ');

    final item = ForemanNotificationItem(
      title: title,
      subtitle: subtitle.isEmpty ? 'A new report was uploaded.' : subtitle,
      receivedAt: submittedAt.toLocal(),
    );

    final nextItems = [item, ...state.items];
    state = state.copyWith(
      items: nextItems.take(50).toList(),
      unreadCount: state.unreadCount + 1,
    );
  }
}

class ForemanNotificationsState {
  const ForemanNotificationsState({
    required this.items,
    required this.unreadCount,
  });

  const ForemanNotificationsState.empty()
    : items = const [],
      unreadCount = 0;

  final List<ForemanNotificationItem> items;
  final int unreadCount;

  ForemanNotificationsState copyWith({
    List<ForemanNotificationItem>? items,
    int? unreadCount,
  }) {
    return ForemanNotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ForemanNotificationItem {
  const ForemanNotificationItem({
    required this.title,
    required this.subtitle,
    required this.receivedAt,
  });

  final String title;
  final String subtitle;
  final DateTime receivedAt;
}

