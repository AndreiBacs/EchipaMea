import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../providers/worker_assigned_projects_provider.dart';
import '../providers/worker_weather_provider.dart';
import 'worker_project_detail_page.dart';

class WorkerHomePage extends ConsumerWidget {
  const WorkerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assigned = ref.watch(workerAssignedProjectsProvider);
    final session = ref.watch(sessionProvider);
    final projectsNotifier = ref.read(projectsProvider.notifier);
    final today = DateTime.now();

    if (assigned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_late_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.workerNoAssignments,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final todaySequences = <_WorkerTodaySequenceEntry>[];
    if (session != null) {
      for (final project in assigned) {
        final sequence = projectsNotifier.sequenceForDay(
          projectId: project.id,
          workerId: session.employeeId,
          day: today,
        );
        if (sequence.orderedPhaseIds.isEmpty) continue;
        final namesById = {
          for (final phase in project.phases) phase.id: phase.name,
        };
        final phaseNames = [
          for (final phaseId in sequence.orderedPhaseIds)
            if (namesById.containsKey(phaseId)) namesById[phaseId]!,
        ];
        if (phaseNames.isEmpty) continue;
        todaySequences.add(
          _WorkerTodaySequenceEntry(
            project: project,
            orderedPhaseNames: phaseNames,
          ),
        );
      }
    }

    final next = assigned.first;
    final rest = assigned.length > 1 ? assigned.sublist(1) : const <Project>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SectionHeader(
          title: l10n.dashboardTodayWorkerSequence,
          icon: Icons.timeline_outlined,
        ),
        const SizedBox(height: 10),
        if (todaySequences.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(l10n.dashboardNoSequencePlannedToday),
            ),
          )
        else
          ...todaySequences.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(entry.project.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.orderedPhaseNames.join(' -> ')),
                      const SizedBox(height: 6),
                      _ProjectWeatherRow(project: entry.project),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  WorkerProjectDetailPage.pathFor(entry.project.id),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        _SectionHeader(title: l10n.workerNextUp, icon: Icons.flag_outlined),
        const SizedBox(height: 10),
        _NextWorkCard(
          project: next,
          statusLabel: workerProjectStatusLabel(l10n, next.status),
          onTap: () => context.push(WorkerProjectDetailPage.pathFor(next.id)),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: l10n.workerUpcomingWork,
            icon: Icons.view_list_outlined,
          ),
          const SizedBox(height: 10),
          ...rest.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                title: Text(p.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(workerProjectStatusLabel(l10n, p.status)),
                    const SizedBox(height: 6),
                    _ProjectWeatherRow(project: p),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(WorkerProjectDetailPage.pathFor(p.id)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _WorkerTodaySequenceEntry {
  const _WorkerTodaySequenceEntry({
    required this.project,
    required this.orderedPhaseNames,
  });

  final Project project;
  final List<String> orderedPhaseNames;
}

String workerProjectStatusLabel(AppLocalizations l10n, ProjectStatus status) {
  return switch (status) {
    ProjectStatus.planned => l10n.statusPlanned,
    ProjectStatus.inProgress => l10n.statusInProgress,
    ProjectStatus.done => l10n.statusDone,
  };
}

class _NextWorkCard extends ConsumerWidget {
  const _NextWorkCard({
    required this.project,
    required this.statusLabel,
    required this.onTap,
  });

  final Project project;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_circle_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              _ProjectWeatherRow(project: project),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.workerViewDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectWeatherRow extends ConsumerWidget {
  const _ProjectWeatherRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latitude = project.latitude;
    final longitude = project.longitude;
    final weatherTexts = _weatherTextsForLocale(context);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    if (latitude == null || longitude == null) {
      return Text(weatherTexts.locationMissing, style: textStyle);
    }

    final weatherAsync = ref.watch(
      workerWeatherProvider(
        WorkerWeatherCoords(latitude: latitude, longitude: longitude),
      ),
    );
    return weatherAsync.when(
      data: (weather) {
        return Row(
          children: [
            Icon(
              _weatherIcon(weather.weatherCode),
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${weather.temperatureC.round()}°C · ${weatherTexts.wind} ${weather.windSpeedKmh.round()} km/h',
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(weatherTexts.loading, style: textStyle),
        ],
      ),
      error: (_, _) => Text(weatherTexts.unavailable, style: textStyle),
    );
  }
}

_WorkerWeatherTexts _weatherTextsForLocale(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return _WorkerWeatherTexts(
    loading: l10n.workerWeatherLoading,
    wind: l10n.workerWeatherWind,
    unavailable: l10n.workerWeatherUnavailable,
    locationMissing: l10n.workerWeatherLocationMissing,
  );
}

class _WorkerWeatherTexts {
  const _WorkerWeatherTexts({
    required this.loading,
    required this.wind,
    required this.unavailable,
    required this.locationMissing,
  });

  final String loading;
  final String wind;
  final String unavailable;
  final String locationMissing;
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
  if (code == 3) return Icons.cloud_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain;
  if (code >= 71 && code <= 86) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_queue_outlined;
}
