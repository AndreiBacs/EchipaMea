enum ProjectStatus {
  planned(label: 'Planned'),
  inProgress(label: 'In Progress'),
  done(label: 'Done');

  const ProjectStatus({required this.label});
  final String label;
}

enum PhaseStatus { notStarted, inProgress, pendingReview, done }
