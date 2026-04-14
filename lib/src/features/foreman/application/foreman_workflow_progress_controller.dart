import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/foreman_workflow_step.dart';

final foremanWorkflowProgressProvider =
    AsyncNotifierProvider<
      ForemanWorkflowProgressNotifier,
      ForemanWorkflowProgressState
    >(ForemanWorkflowProgressNotifier.new);

class ForemanWorkflowProgressState {
  const ForemanWorkflowProgressState({
    required this.completedSteps,
    required this.cardDismissed,
  });

  final Set<ForemanWorkflowStep> completedSteps;
  final bool cardDismissed;

  bool get allStepsCompleted =>
      completedSteps.length == ForemanWorkflowStep.values.length;

  int get completedCount => completedSteps.length;

  ForemanWorkflowProgressState copyWith({
    Set<ForemanWorkflowStep>? completedSteps,
    bool? cardDismissed,
  }) {
    return ForemanWorkflowProgressState(
      completedSteps: completedSteps ?? this.completedSteps,
      cardDismissed: cardDismissed ?? this.cardDismissed,
    );
  }
}

class ForemanWorkflowProgressNotifier
    extends AsyncNotifier<ForemanWorkflowProgressState> {
  static const _completedStepsKey = 'foreman_workflow_completed_steps';
  static const _cardDismissedKey = 'foreman_workflow_card_dismissed';

  @override
  Future<ForemanWorkflowProgressState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_completedStepsKey) ?? const <String>[];
    final completed = stored
        .map(_stepFromStorage)
        .whereType<ForemanWorkflowStep>()
        .toSet();
    final dismissed = prefs.getBool(_cardDismissedKey) ?? false;
    return ForemanWorkflowProgressState(
      completedSteps: completed,
      cardDismissed: dismissed,
    );
  }

  Future<void> markComplete(ForemanWorkflowStep step) async {
    final current = await future;
    if (current.completedSteps.contains(step)) {
      return;
    }
    final updatedSteps = {...current.completedSteps, step};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _completedStepsKey,
      updatedSteps.map(_stepToStorage).toList(),
    );
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(completedSteps: updatedSteps));
  }

  Future<void> dismissCard() async {
    final current = await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cardDismissedKey, true);
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(cardDismissed: true));
  }

  Future<void> restoreCard() async {
    final current = await future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cardDismissedKey, false);
    if (!ref.mounted) return;
    state = AsyncData(current.copyWith(cardDismissed: false));
  }

  ForemanWorkflowStep? _stepFromStorage(String value) {
    for (final step in ForemanWorkflowStep.values) {
      if (_stepToStorage(step) == value) {
        return step;
      }
    }
    return null;
  }

  String _stepToStorage(ForemanWorkflowStep step) {
    return switch (step) {
      ForemanWorkflowStep.addClient => 'add_client',
      ForemanWorkflowStep.createProject => 'create_project',
      ForemanWorkflowStep.configurePhase => 'configure_phase',
      ForemanWorkflowStep.addEmployee => 'add_employee',
    };
  }
}
