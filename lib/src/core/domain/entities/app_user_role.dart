enum AppUserRole {
  foreman(label: 'Foreman'),
  worker(label: 'Worker');

  const AppUserRole({required this.label});

  final String label;
}
