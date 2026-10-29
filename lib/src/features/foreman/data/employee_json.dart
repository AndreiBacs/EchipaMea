import '../../../core/domain/entities/worker_role.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/employee.dart';

Employee employeeFromJson(Json json) => Employee(
  id: json['id'] as String,
  name: json['name'] as String,
  role: WorkerRole.values.asNameMap()[json['role']] ?? WorkerRole.generalWorker,
  email: json['email'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  workStartHour: (json['workStartHour'] as num).toInt(),
  workEndHour: (json['workEndHour'] as num).toInt(),
  workingDays: {
    for (final day in json['workingDays'] as List) (day as num).toInt(),
  },
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  isActive: json['isActive'] as bool? ?? true,
);

/// The editable fields, for both create and update. A missing location is
/// left out rather than sent as null, because null clears it on the server
/// and no form edits it.
Json employeeToJson(Employee employee) => {
  'name': employee.name,
  'role': employee.role.name,
  'email': employee.email,
  'phone': employee.phone,
  'workStartHour': employee.workStartHour,
  'workEndHour': employee.workEndHour,
  'workingDays': employee.workingDays.toList()..sort(),
  'latitude': ?employee.latitude,
  'longitude': ?employee.longitude,
  'isActive': employee.isActive,
};
