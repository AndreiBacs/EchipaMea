import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/realtime_ticket_api.dart';
import '../../foreman/presentation/providers/team_controller.dart';

final workerTelemetryCoordinatorProvider = Provider<WorkerTelemetryCoordinator>(
  (ref) {
    final coordinator = WorkerTelemetryCoordinator(
      fetchTicket: () =>
          ref.read(workerRealtimeTicketApiProvider).fetchTicket(),
    );
    ref.listen<AsyncValue<WorkerSession?>>(sessionProvider, (_, next) {
      coordinator.updateSession(next.value);
    }, fireImmediately: true);
    ref.listen<List<Employee>>(teamProvider, (_, next) {
      coordinator.updateEmployees(next);
    }, fireImmediately: true);
    ref.onDispose(coordinator.dispose);
    return coordinator;
  },
);

class WorkerTelemetryCoordinator {
  WorkerTelemetryCoordinator({required Future<String?> Function() fetchTicket})
    : _fetchTicket = fetchTicket;

  /// How often to read GPS and send a `worker_location` message on the telemetry WebSocket.
  static const Duration _pollInterval = Duration(minutes: 30);

  WorkerSession? _session;
  Map<String, Employee> _employeesById = const {};
  Timer? _timer;
  WebSocketChannel? _channel;
  bool _locationDeniedForever = false;
  bool _connecting = false;

  /// Mints a single-use socket ticket with the worker's token, refreshing it
  /// first if it has expired. Null means "do not connect".
  final Future<String?> Function() _fetchTicket;

  void updateSession(WorkerSession? next) {
    _session = next;
    if (_session == null) {
      _stop();
      return;
    }
    _start();
  }

  void updateEmployees(List<Employee> employees) {
    _employeesById = {for (final employee in employees) employee.id: employee};
  }

  void dispose() {
    _stop();
  }

  void _start() {
    _timer ??= Timer.periodic(_pollInterval, (_) => _tick());
    unawaited(_tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _disconnectSocket();
  }

  Future<void> _tick() async {
    final session = _session;
    if (session == null) {
      return;
    }

    final employee = _employeesById[session.employeeId];
    if (employee == null) {
      _disconnectSocket();
      return;
    }

    if (!_isInsideWorkingSchedule(DateTime.now(), employee)) {
      _disconnectSocket();
      return;
    }

    if (AppEnv.workerTelemetryWsUrl.trim().isEmpty) {
      return;
    }

    if (!await _canUseLocation()) {
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return;
    }

    final channel = await _ensureSocket(session);
    if (channel == null) {
      return;
    }

    final payload = {
      'type': 'worker_location',
      'employeeId': session.employeeId,
      'employeeName': session.employeeName,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {
      _disconnectSocket();
    }
  }

  bool _isInsideWorkingSchedule(DateTime now, Employee employee) {
    final start = employee.workStartHour;
    final end = employee.workEndHour;
    final allowedDays = employee.workingDays;
    if (!allowedDays.contains(now.weekday)) {
      return false;
    }
    if (start == end) {
      return false;
    }
    if (start < end) {
      return now.hour >= start && now.hour < end;
    }
    return now.hour >= start || now.hour < end;
  }

  Future<bool> _canUseLocation() async {
    if (_locationDeniedForever) {
      return false;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _locationDeniedForever = true;
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Opens the telemetry socket, proving who we are first.
  ///
  /// The server takes no unauthenticated sockets, so a ticket is fetched with
  /// the worker's session token and passed as `?ticket=` -- Dart cannot set
  /// headers on a WebSocket from Flutter web. Without one we do not connect;
  /// telemetry is best-effort by design and a missed 30-minute sample is a far
  /// smaller problem than an unidentified position in someone's database.
  Future<WebSocketChannel?> _ensureSocket(WorkerSession session) async {
    final existing = _channel;
    if (existing != null) {
      return existing;
    }
    if (_connecting) return null;

    _connecting = true;
    try {
      final ticket = await _fetchTicket();
      if (ticket == null) return null;

      final uri = socketUriWithTicket(AppEnv.workerTelemetryWsUrl, ticket);
      if (uri == null) return null;

      // The session may have ended while the ticket request was in flight.
      if (_session == null) return null;

      return _openSocket(uri);
    } catch (_) {
      return null;
    } finally {
      _connecting = false;
    }
  }

  WebSocketChannel _openSocket(Uri uri) {
    final created = WebSocketChannel.connect(uri);
    created.stream.listen(
      (_) {},
      onError: (_) => _disconnectSocket(),
      onDone: _disconnectSocket,
      cancelOnError: true,
    );
    _channel = created;
    return created;
  }

  void _disconnectSocket() {
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close() ?? Future<void>.value());
  }
}
