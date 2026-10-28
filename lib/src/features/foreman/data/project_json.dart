import '../../../core/network/api_client.dart';
import '../../../core/util/day_key.dart';
import '../domain/entities/project.dart';

Project projectFromJson(Json json) => Project(
  id: json['id'] as String,
  name: json['name'] as String,
  clientId: json['clientId'] as String,
  status:
      ProjectStatus.values.asNameMap()[json['status']] ?? ProjectStatus.planned,
  workers: _strings(json['workers']),
  assignedEmployeeIds: _strings(json['assignedEmployeeIds']),
  useClientAddress: json['useClientAddress'] as bool? ?? true,
  addressLine1: json['addressLine1'] as String? ?? '',
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  zipCode: json['zipCode'] as String? ?? '',
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  phases: [
    for (final phase in json['phases'] as List? ?? const [])
      phaseFromJson(phase as Json),
  ],
);

ProjectPhase phaseFromJson(Json json) => ProjectPhase(
  id: json['id'] as String,
  name: json['name'] as String,
  startDate: dayFromKey(json['startDate'] as String),
  endDate: dayFromKey(json['endDate'] as String),
  description: json['description'] as String? ?? '',
  assignedEmployeeIds: _strings(json['assignedEmployeeIds']),
  status:
      PhaseStatus.values.asNameMap()[json['status']] ?? PhaseStatus.notStarted,
  submittedAt: _dateTime(json['submittedAt']),
  submittedByEmployeeIds: _strings(json['submittedByEmployeeIds']),
  reviewedAt: _dateTime(json['reviewedAt']),
  reviewedByForemanId: json['reviewedByForemanId'] as String?,
  reviewNotes: json['reviewNotes'] as String?,
  workInstructions: [
    for (final item in json['workInstructions'] as List? ?? const [])
      _instructionFromJson(item as Json),
  ],
);

PhaseWorkInstruction _instructionFromJson(Json json) => PhaseWorkInstruction(
  id: json['id'] as String,
  text: json['text'] as String? ?? '',
  photoMediaIds: _mediaIds(json['photos']),
  audioMediaIds: _mediaIds(json['audio']),
);

/// The project's own editable fields, for PATCH. Its phases change through
/// the phase endpoints; `status` and `workers` are derived by the server.
Json projectFieldsToJson(Project project) => {
  'name': project.name,
  'clientId': project.clientId,
  'useClientAddress': project.useClientAddress,
  'addressLine1': project.addressLine1,
  'city': project.city,
  'state': project.state,
  'zipCode': project.zipCode,
  'latitude': ?project.latitude,
  'longitude': ?project.longitude,
  'assignedEmployeeIds': project.assignedEmployeeIds,
};

/// A new project with its phases inline, for POST.
Json projectCreateToJson(Project project) => {
  ...projectFieldsToJson(project),
  'phases': [for (final phase in project.phases) phaseToJson(phase)],
};

/// A phase's editable fields, for create and PATCH. Ids are left out: the
/// server assigns its own, and would otherwise keep a draft id the app made up.
/// The instruction list is sent whole, because the server replaces it.
Json phaseToJson(ProjectPhase phase) => {
  'name': phase.name,
  'startDate': dayKey(phase.startDate),
  'endDate': dayKey(phase.endDate),
  'description': phase.description,
  'assignedEmployeeIds': phase.assignedEmployeeIds,
  'workInstructions': [
    for (final instruction in phase.workInstructions)
      {
        'text': instruction.text,
        'photoMediaIds': instruction.photoMediaIds,
        'audioMediaIds': instruction.audioMediaIds,
      },
  ],
};

List<String> _strings(Object? value) => [
  for (final item in value as List? ?? const []) item as String,
];

List<String> _mediaIds(Object? value) => [
  for (final item in value as List? ?? const []) (item as Json)['id'] as String,
];

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
