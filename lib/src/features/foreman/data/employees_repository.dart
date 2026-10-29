import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/domain/entities/worker_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/employee.dart';
import 'employee_json.dart';

final employeesRepositoryProvider = Provider<EmployeesRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiEmployeesRepository(ref.watch(foremanApiProvider))
      : InMemoryEmployeesRepository(),
);

abstract interface class EmployeesRepository {
  /// Every employee, deactivated ones included; deleted ones are gone.
  Future<List<Employee>> list();

  /// Saves a new employee; [draft]'s id is ignored and the stored one returned.
  Future<Employee> create(Employee draft);

  Future<Employee> update(Employee employee);
}

class ApiEmployeesRepository implements EmployeesRepository {
  ApiEmployeesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Employee>> list() async => [
    for (final json in await _api.getAllPages('/employees'))
      employeeFromJson(json),
  ];

  @override
  Future<Employee> create(Employee draft) async => employeeFromJson(
    await _api.post('/employees', body: employeeToJson(draft)),
  );

  @override
  Future<Employee> update(Employee employee) async => employeeFromJson(
    await _api.patch(
      '/employees/${Uri.encodeComponent(employee.id)}',
      body: employeeToJson(employee),
    ),
  );
}

/// Mock mode: the demo crew, kept for as long as the app runs.
class InMemoryEmployeesRepository implements EmployeesRepository {
  final _employees = [..._demoEmployees];

  @override
  Future<List<Employee>> list() async => List.unmodifiable(_employees);

  @override
  Future<Employee> create(Employee draft) async {
    final created = draft.copyWith(
      id: 'e${_employees.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _employees.add(created);
    return created;
  }

  @override
  Future<Employee> update(Employee employee) async {
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index < 0) throw const ApiException(status: 404, code: 'NOT_FOUND');
    _employees[index] = employee;
    return employee;
  }
}

const _demoEmployees = [
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
