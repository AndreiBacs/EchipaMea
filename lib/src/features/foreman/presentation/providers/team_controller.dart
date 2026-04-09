import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/worker_role.dart';

final teamProvider = NotifierProvider<TeamNotifier, List<Employee>>(
  TeamNotifier.new,
);

class TeamNotifier extends Notifier<List<Employee>> {
  @override
  List<Employee> build() {
    return const [
      Employee(
        id: 'e1',
        name: 'Andrei D.',
        role: WorkerRole.electrician,
        email: 'andrei@example.com',
        phone: '+40 721 000 111',
        latitude: 46.7729,
        longitude: 23.6243,
        workStartHour: 7,
        workEndHour: 16,
        workingDays: {1, 2, 3, 4, 5},
      ),
      Employee(
        id: 'e2',
        name: 'Mihai S.',
        role: WorkerRole.plumber,
        email: 'mihai@example.com',
        phone: '+40 722 000 222',
        latitude: 46.7686,
        longitude: 23.6041,
        workStartHour: 8,
        workEndHour: 17,
        workingDays: {1, 2, 3, 4, 5},
      ),
      Employee(
        id: 'e3',
        name: 'Ioana R.',
        role: WorkerRole.generalWorker,
        email: 'ioana@example.com',
        phone: '+40 723 000 333',
        latitude: 46.7614,
        longitude: 23.5918,
        workStartHour: 9,
        workEndHour: 18,
        workingDays: {1, 2, 3, 4, 5, 6},
      ),
    ];
  }

  void addEmployee({
    required String name,
    required WorkerRole role,
    required String email,
    required String phone,
    required int workStartHour,
    required int workEndHour,
    required Set<int> workingDays,
    double? latitude,
    double? longitude,
  }) {
    final nextId =
        'e${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Employee(
        id: nextId,
        name: name,
        role: role,
        email: email,
        phone: phone,
        workStartHour: workStartHour,
        workEndHour: workEndHour,
        workingDays: workingDays,
        latitude: latitude,
        longitude: longitude,
      ),
    ];
  }

  void updateEmployee({
    required String id,
    required String name,
    required WorkerRole role,
    required String email,
    required String phone,
    required int workStartHour,
    required int workEndHour,
    required Set<int> workingDays,
    double? latitude,
    double? longitude,
  }) {
    state = [
      for (final employee in state)
        if (employee.id == id)
          employee.copyWith(
            name: name,
            role: role,
            email: email,
            phone: phone,
            workStartHour: workStartHour,
            workEndHour: workEndHour,
            workingDays: workingDays,
            latitude: latitude,
            longitude: longitude,
          )
        else
          employee,
    ];
  }

  Employee? findById(String id) {
    for (final employee in state) {
      if (employee.id == id) return employee;
    }
    return null;
  }
}

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
