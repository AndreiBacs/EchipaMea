enum ForemanNotificationKind {
  workerReportSubmitted,
  phaseApproved,
  phaseRejected,
  workerArrived,

  /// A kind this app version does not know yet.
  other,
}

/// Something that happened that the foreman should see. Only data is kept
/// here; the title and text are worded when shown, in the current language.
class ForemanNotificationItem {
  const ForemanNotificationItem({
    required this.id,
    required this.kind,
    required this.occurredAt,
    this.projectId,
    this.phaseId,
    this.employeeId,
    this.projectName = '',
    this.phaseName = '',
    this.employeeName = '',
    this.readAt,
  });

  final String id;
  final ForemanNotificationKind kind;
  final DateTime occurredAt;
  final String? projectId;
  final String? phaseId;
  final String? employeeId;

  /// Names as they were when it happened; a later rename does not rewrite
  /// history.
  final String projectName;
  final String phaseName;
  final String employeeName;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  ForemanNotificationItem markedRead(DateTime at) => isRead
      ? this
      : ForemanNotificationItem(
          id: id,
          kind: kind,
          occurredAt: occurredAt,
          projectId: projectId,
          phaseId: phaseId,
          employeeId: employeeId,
          projectName: projectName,
          phaseName: phaseName,
          employeeName: employeeName,
          readAt: at,
        );
}

class ForemanNotificationsState {
  const ForemanNotificationsState({
    required this.items,
    required this.unreadCount,
  });

  const ForemanNotificationsState.empty() : items = const [], unreadCount = 0;

  /// Newest first.
  final List<ForemanNotificationItem> items;

  /// Across all of the foreman's notifications, not only [items].
  final int unreadCount;

  ForemanNotificationsState allRead(DateTime at) => ForemanNotificationsState(
    items: [for (final item in items) item.markedRead(at)],
    unreadCount: 0,
  );
}
