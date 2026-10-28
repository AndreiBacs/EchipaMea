/// The order in which one worker takes on a project's phases on one day.
class DailyWorkerSequence {
  const DailyWorkerSequence({
    required this.projectId,
    required this.dayKey,
    required this.workerId,
    required this.orderedPhaseIds,
    this.suggestedPhaseIds = const [],
    this.isManual = false,
  });

  final String projectId;
  final String dayKey;
  final String workerId;

  /// The effective order: the foreman's when [isManual], else the suggestion.
  final List<String> orderedPhaseIds;

  /// The worker's phases whose date window covers the day, by start date and
  /// then name.
  final List<String> suggestedPhaseIds;

  /// True when a foreman saved an explicit order for this day.
  final bool isManual;
}

/// Every worker's sequence for one day.
class DaySequences {
  const DaySequences({required this.dayKey, this.sequences = const []});

  final String dayKey;
  final List<DailyWorkerSequence> sequences;

  /// The sequence of [workerId] on [projectId]; empty when they have nothing
  /// to do there that day.
  DailyWorkerSequence of({
    required String projectId,
    required String workerId,
  }) {
    for (final sequence in sequences) {
      if (sequence.projectId == projectId && sequence.workerId == workerId) {
        return sequence;
      }
    }
    return DailyWorkerSequence(
      projectId: projectId,
      dayKey: dayKey,
      workerId: workerId,
      orderedPhaseIds: const [],
    );
  }
}
