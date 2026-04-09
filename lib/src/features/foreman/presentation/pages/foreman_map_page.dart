import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../providers/projects_controller.dart';
import '../providers/team_controller.dart';

class ForemanMapPage extends ConsumerWidget {
  const ForemanMapPage({super.key});

  static const _defaultCenter = LatLng(46.7700, 23.6000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final projects = ref
        .watch(projectsProvider)
        .where((project) => project.status == ProjectStatus.inProgress)
        .toList();
    final employees = ref.watch(teamProvider);
    final allKnownPoints = <LatLng>[
      for (final project in projects)
        if (project.latitude != null && project.longitude != null)
          LatLng(project.latitude!, project.longitude!),
      for (final employee in employees)
        if (employee.latitude != null && employee.longitude != null)
          LatLng(employee.latitude!, employee.longitude!),
    ];
    final center = allKnownPoints.isEmpty ? _defaultCenter : _centerOf(allKnownPoints);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.mapOverviewTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${projects.length} ${l10n.inProgress} • ${employees.length} ${l10n.workerCountSuffix}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.echipamea.app',
                  ),
                  MarkerLayer(
                    markers: [
                      ..._buildProjectMarkers(context, projects),
                      ..._buildWorkerMarkers(context, employees),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendChip(
                color: Colors.orange.shade700,
                icon: Icons.construction,
                label: l10n.mapLegendProjects,
              ),
              _LegendChip(
                color: Colors.blue.shade700,
                icon: Icons.person_pin_circle,
                label: l10n.mapLegendWorkers,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Marker> _buildProjectMarkers(BuildContext context, List<Project> projects) {
    return [
      for (final project in projects)
        Marker(
          point: _projectPoint(project),
          width: 190,
          height: 72,
          child: _MarkerBubble(
            color: Colors.orange.shade700,
            icon: Icons.construction,
            title: project.name,
          ),
        ),
    ];
  }

  List<Marker> _buildWorkerMarkers(BuildContext context, List<Employee> employees) {
    return [
      for (final employee in employees)
        Marker(
          point: _workerPoint(employee),
          width: 180,
          height: 72,
          child: _MarkerBubble(
            color: Colors.blue.shade700,
            icon: Icons.person_pin_circle,
            title: employee.name,
            subtitle: employee.role,
          ),
        ),
    ];
  }

  LatLng _projectPoint(Project project) {
    if (project.latitude != null && project.longitude != null) {
      return LatLng(project.latitude!, project.longitude!);
    }
    return _seededOffset(_defaultCenter, project.id);
  }

  LatLng _workerPoint(Employee employee) {
    if (employee.latitude != null && employee.longitude != null) {
      return LatLng(employee.latitude!, employee.longitude!);
    }
    return _seededOffset(_defaultCenter, employee.id);
  }

  LatLng _seededOffset(LatLng base, String seed) {
    final hash = seed.codeUnits.fold<int>(0, (acc, value) => acc + value);
    final latDelta = ((hash % 20) - 10) / 1000;
    final lngDelta = (((hash ~/ 3) % 20) - 10) / 1000;
    return LatLng(base.latitude + latDelta, base.longitude + lngDelta);
  }

  LatLng _centerOf(List<LatLng> points) {
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }
}

class _MarkerBubble extends StatelessWidget {
  const _MarkerBubble({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                offset: Offset(0, 2),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
