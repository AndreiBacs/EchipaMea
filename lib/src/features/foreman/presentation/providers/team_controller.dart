import 'package:flutter_riverpod/flutter_riverpod.dart';

final teamProvider = NotifierProvider<TeamNotifier, List<Employee>>(
  TeamNotifier.new,
);

class TeamNotifier extends Notifier<List<Employee>> {
  @override
  List<Employee> build() {
    return const [
      Employee(id: 'e1', name: 'Andrei D.', role: 'Electrician'),
      Employee(id: 'e2', name: 'Mihai S.', role: 'Plumber'),
      Employee(id: 'e3', name: 'Ioana R.', role: 'General Worker'),
    ];
  }

  void addEmployee({required String name, required String role}) {
    final nextId =
        'e${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [...state, Employee(id: nextId, name: name, role: role)];
  }

  void updateEmployee({
    required String id,
    required String name,
    required String role,
  }) {
    state = [
      for (final employee in state)
        if (employee.id == id)
          employee.copyWith(name: name, role: role)
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
  const Employee({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  Employee copyWith({String? name, String? role}) {
    return Employee(id: id, name: name ?? this.name, role: role ?? this.role);
  }
}
