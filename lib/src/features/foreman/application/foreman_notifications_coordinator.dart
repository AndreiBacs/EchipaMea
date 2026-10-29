import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/backoff.dart';
import '../../../core/network/realtime_ticket_api.dart';
import '../data/notifications_repository.dart';
import '../domain/entities/foreman_notification.dart';
import '../presentation/providers/projects_controller.dart';

final foremanNotificationsProvider =
    AsyncNotifierProvider<
      ForemanNotificationsNotifier,
      ForemanNotificationsState
    >(ForemanNotificationsNotifier.new);

/// The foreman's notifications, and the live feed that says when there are
/// new ones.
///
/// The server stores every notification; the socket only announces them. So
/// a `worker_report_submitted` frame triggers a refetch of the list and of the
/// projects (the report also moved its phase to pendingReview), and nothing
/// is lost while the socket is down: it reconnects with backoff for as long
/// as a foreman is signed in, and refetches once it is back.
class ForemanNotificationsNotifier
    extends AsyncNotifier<ForemanNotificationsState> {
  WebSocketChannel? _channel;
  bool _connecting = false;
  Timer? _reconnectTimer;
  final _backoff = Backoff();

  /// Set while recovering from a dropped connection, so the next successful
  /// one also refetches what was missed.
  bool _missedEvents = false;

  NotificationsRepository get _repository =>
      ref.read(notificationsRepositoryProvider);

  @override
  Future<ForemanNotificationsState> build() async {
    final repository = ref.watch(notificationsRepositoryProvider);
    ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (_, next) {
      if (next.asData?.value == null) {
        _stop();
      } else {
        unawaited(_connect());
      }
    }, fireImmediately: true);
    ref.onDispose(_stop);
    if (!await watchForemanScope(ref)) {
      return const ForemanNotificationsState.empty();
    }
    return repository.latest();
  }

  /// Reloads the list. A failure keeps the one already shown.
  Future<void> refresh() async {
    try {
      final latest = await _repository.latest();
      if (ref.mounted) state = AsyncData(latest);
    } catch (_) {}
  }

  /// The foreman opened the list, so everything in it is read. The badge
  /// clears at once; if the server cannot be told, it catches up on the next
  /// refresh.
  Future<void> markAllRead() async {
    final current = state.value;
    if (current != null) state = AsyncData(current.allRead(DateTime.now()));
    try {
      await _repository.markAllRead();
      await refresh();
    } catch (_) {}
  }

  /// Opens the feed, proving who we are first.
  ///
  /// A ticket is fetched with the foreman's token and passed as `?ticket=`,
  /// because Dart cannot set headers on a WebSocket from Flutter web. Without
  /// a ticket we do not connect: failing closed costs a notification badge,
  /// failing open would cost the company's data.
  Future<void> _connect() async {
    if (_channel != null || _connecting) return;
    final endpoint = AppEnv.foremanNotificationsWsUrl.trim();
    // Mock mode has no server to mint a ticket.
    if (endpoint.isEmpty || !AppEnv.hasBackend) return;

    _reconnectTimer?.cancel();
    _connecting = true;
    try {
      final ticket = await ref
          .read(foremanRealtimeTicketApiProvider)
          .fetchTicket();
      // Signed out, or rebuilt for another foreman, while the ticket was
      // being fetched.
      if (!ref.mounted || !_signedIn) return;
      final uri = ticket == null ? null : socketUriWithTicket(endpoint, ticket);
      if (uri == null) {
        _scheduleReconnect();
        return;
      }

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.stream.listen(
        _onMessage,
        onError: (_) => _onClosed(channel),
        onDone: () => _onClosed(channel),
        cancelOnError: true,
      );
      unawaited(
        channel.ready.then((_) {
          _backoff.reset();
          if (_missedEvents) {
            _missedEvents = false;
            unawaited(refresh());
          }
        }, onError: (_) {}),
      );
    } catch (_) {
      if (ref.mounted) _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  bool get _signedIn => ref.read(authSessionProvider).asData?.value != null;

  void _onClosed(WebSocketChannel channel) {
    // A socket we already replaced or closed on purpose.
    if (!identical(_channel, channel)) return;
    _channel = null;
    if (ref.mounted && _signedIn) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _missedEvents = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff.next(), () {
      if (ref.mounted && _signedIn) unawaited(_connect());
    });
  }

  void _stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoff.reset();
    _missedEvents = false;
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close() ?? Future<void>.value());
  }

  void _onMessage(dynamic raw) {
    Object? data;
    try {
      data = raw is String ? jsonDecode(raw) : null;
    } catch (_) {
      return;
    }
    if (data is! Map<String, dynamic>) return;
    if (data['type'] != 'worker_report_submitted') return;
    if (!ref.mounted) return;

    unawaited(refresh());
    ref.invalidate(projectsProvider);
  }
}
