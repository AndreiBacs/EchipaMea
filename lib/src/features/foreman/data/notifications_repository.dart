import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/foreman_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiNotificationsRepository(ref.watch(foremanApiProvider))
      : const EmptyNotificationsRepository(),
);

/// The signed-in foreman's notifications. Read state is per foreman: one
/// opening the list does not clear the badge on a colleague's phone.
abstract interface class NotificationsRepository {
  /// The newest notifications, and the unread count across all of them.
  Future<ForemanNotificationsState> latest();

  Future<void> markAllRead();
}

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._api);

  /// How many the list shows; older ones stay on the server.
  static const pageSize = 50;

  final ApiClient _api;

  @override
  Future<ForemanNotificationsState> latest() async {
    final json =
        await _api.get('/notifications', query: {'limit': '$pageSize'}) as Json;
    return ForemanNotificationsState(
      items: [
        for (final item in json['items'] as List? ?? const [])
          _itemFromJson(item as Json),
      ],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> markAllRead() => _api.post('/notifications/read-all');

  static ForemanNotificationItem _itemFromJson(Json json) {
    final payload = json['payload'] is Json
        ? json['payload'] as Json
        : const <String, dynamic>{};
    String text(String key) => payload[key] is String ? payload[key] : '';
    return ForemanNotificationItem(
      id: json['id'] as String,
      kind:
          ForemanNotificationKind.values.asNameMap()[json['kind']] ??
          ForemanNotificationKind.other,
      occurredAt: DateTime.parse(json['occurredAt'] as String).toLocal(),
      projectId: json['projectId'] as String?,
      phaseId: json['phaseId'] as String?,
      employeeId: json['employeeId'] as String?,
      projectName: text('projectName'),
      phaseName: text('phaseName'),
      employeeName: text('employeeName'),
      readAt: json['readAt'] is String
          ? DateTime.parse(json['readAt'] as String).toLocal()
          : null,
    );
  }
}

/// Mock mode: no server records events for the foreman, so there are none.
class EmptyNotificationsRepository implements NotificationsRepository {
  const EmptyNotificationsRepository();

  @override
  Future<ForemanNotificationsState> latest() async =>
      const ForemanNotificationsState.empty();

  @override
  Future<void> markAllRead() async {}
}
