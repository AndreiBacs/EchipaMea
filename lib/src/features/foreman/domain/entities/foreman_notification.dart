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
