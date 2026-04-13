import '../../../../core/domain/entities/worker_role.dart';

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.workStartHour,
    required this.workEndHour,
    required this.workingDays,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final WorkerRole role;
  final String email;
  final String phone;
  final int workStartHour;
  final int workEndHour;
  final Set<int> workingDays;
  final double? latitude;
  final double? longitude;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  Employee copyWith({
    String? name,
    WorkerRole? role,
    String? email,
    String? phone,
    int? workStartHour,
    int? workEndHour,
    Set<int>? workingDays,
    double? latitude,
    double? longitude,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      workStartHour: workStartHour ?? this.workStartHour,
      workEndHour: workEndHour ?? this.workEndHour,
      workingDays: workingDays ?? this.workingDays,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
