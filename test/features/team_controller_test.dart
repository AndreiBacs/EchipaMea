import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/domain/entities/worker_role.dart';
import 'package:echipa_mea/src/features/foreman/presentation/providers/team_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('TeamNotifier initial state', () {
    test('starts with 3 demo employees', () {
      expect(container.read(teamProvider).length, 3);
    });

    test('first demo employee has id e1', () {
      expect(container.read(teamProvider).first.id, 'e1');
    });

    test('demo employees have required fields populated', () {
      for (final emp in container.read(teamProvider)) {
        expect(emp.id, isNotEmpty);
        expect(emp.name, isNotEmpty);
        expect(emp.role, isA<WorkerRole>());
        expect(emp.email, isNotEmpty);
        expect(emp.phone, isNotEmpty);
        expect(emp.workingDays, isNotEmpty);
      }
    });
  });

  group('TeamNotifier.addEmployee', () {
    test('increases employee count by one', () {
      container.read(teamProvider.notifier).addEmployee(
            name: 'New Worker',
            role: WorkerRole.carpenter,
            email: 'new@example.com',
            phone: '+40 700 000 001',
            workStartHour: 8,
            workEndHour: 17,
            workingDays: {1, 2, 3, 4, 5},
          );
      expect(container.read(teamProvider).length, 4);
    });

    test('added employee is appended to the end', () {
      container.read(teamProvider.notifier).addEmployee(
            name: 'Last Employee',
            role: WorkerRole.helper,
            email: 'last@example.com',
            phone: '0700',
            workStartHour: 9,
            workEndHour: 18,
            workingDays: {1},
          );
      expect(container.read(teamProvider).last.name, 'Last Employee');
    });

    test('added employee has all fields set correctly', () {
      container.read(teamProvider.notifier).addEmployee(
            name: 'Full Fields',
            role: WorkerRole.welder,
            email: 'ff@example.com',
            phone: '+40 700 111 222',
            workStartHour: 6,
            workEndHour: 14,
            workingDays: {1, 2, 3},
            latitude: 46.0,
            longitude: 23.0,
          );
      final added = container.read(teamProvider).last;
      expect(added.name, 'Full Fields');
      expect(added.role, WorkerRole.welder);
      expect(added.email, 'ff@example.com');
      expect(added.phone, '+40 700 111 222');
      expect(added.workStartHour, 6);
      expect(added.workEndHour, 14);
      expect(added.workingDays, {1, 2, 3});
      expect(added.latitude, 46.0);
      expect(added.longitude, 23.0);
    });

    test('added employee without coordinates has null lat/long', () {
      container.read(teamProvider.notifier).addEmployee(
            name: 'No Coords',
            role: WorkerRole.painter,
            email: 'nc@example.com',
            phone: '0',
            workStartHour: 9,
            workEndHour: 17,
            workingDays: {1},
          );
      final added = container.read(teamProvider).last;
      expect(added.latitude, isNull);
      expect(added.longitude, isNull);
    });

    test('generated ids are unique for successive adds', () {
      container.read(teamProvider.notifier).addEmployee(
            name: 'A',
            role: WorkerRole.mason,
            email: 'a@a.com',
            phone: '0',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );
      container.read(teamProvider.notifier).addEmployee(
            name: 'B',
            role: WorkerRole.mason,
            email: 'b@b.com',
            phone: '0',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );
      final employees = container.read(teamProvider);
      final ids = employees.map((e) => e.id).toSet();
      expect(ids.length, employees.length);
    });
  });

  group('TeamNotifier.updateEmployee', () {
    test('updates name for existing employee', () {
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e1',
            name: 'Updated Name',
            role: WorkerRole.electrician,
            email: 'andrei@example.com',
            phone: '+40 721 000 111',
            workStartHour: 7,
            workEndHour: 16,
            workingDays: {1, 2, 3, 4, 5},
          );
      final updated = container
          .read(teamProvider)
          .firstWhere((e) => e.id == 'e1');
      expect(updated.name, 'Updated Name');
    });

    test('updates role for existing employee', () {
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e2',
            name: 'Mihai S.',
            role: WorkerRole.electrician,
            email: 'mihai@example.com',
            phone: '+40 722 000 222',
            workStartHour: 8,
            workEndHour: 17,
            workingDays: {1, 2, 3, 4, 5},
          );
      final updated = container
          .read(teamProvider)
          .firstWhere((e) => e.id == 'e2');
      expect(updated.role, WorkerRole.electrician);
    });

    test('updates working hours for existing employee', () {
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e1',
            name: 'Andrei D.',
            role: WorkerRole.electrician,
            email: 'andrei@example.com',
            phone: '+40 721 000 111',
            workStartHour: 9,
            workEndHour: 18,
            workingDays: {1, 2, 3, 4, 5},
          );
      final updated = container
          .read(teamProvider)
          .firstWhere((e) => e.id == 'e1');
      expect(updated.workStartHour, 9);
      expect(updated.workEndHour, 18);
    });

    test('updates working days for existing employee', () {
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e1',
            name: 'Andrei D.',
            role: WorkerRole.electrician,
            email: 'andrei@example.com',
            phone: '+40 721 000 111',
            workStartHour: 7,
            workEndHour: 16,
            workingDays: {6, 7},
          );
      final updated = container
          .read(teamProvider)
          .firstWhere((e) => e.id == 'e1');
      expect(updated.workingDays, {6, 7});
    });

    test('does not change total count on update', () {
      final before = container.read(teamProvider).length;
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e1',
            name: 'X',
            role: WorkerRole.helper,
            email: 'x@x.com',
            phone: '0',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );
      expect(container.read(teamProvider).length, before);
    });

    test('does not affect other employees when updating one', () {
      container.read(teamProvider.notifier).updateEmployee(
            id: 'e1',
            name: 'Changed',
            role: WorkerRole.helper,
            email: 'c@c.com',
            phone: '0',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );
      final e2 = container.read(teamProvider).firstWhere((e) => e.id == 'e2');
      expect(e2.name, 'Mihai S.');
    });

    test('unknown id does not change state', () {
      final before =
          container.read(teamProvider).map((e) => e.name).toList();
      container.read(teamProvider.notifier).updateEmployee(
            id: 'nonexistent',
            name: 'Ghost',
            role: WorkerRole.helper,
            email: 'g@g.com',
            phone: '0',
            workStartHour: 8,
            workEndHour: 16,
            workingDays: {1},
          );
      final after = container.read(teamProvider).map((e) => e.name).toList();
      expect(after, before);
    });
  });

  group('TeamNotifier.findById', () {
    test('returns correct employee for valid id', () {
      final emp = container.read(teamProvider.notifier).findById('e1');
      expect(emp, isNotNull);
      expect(emp!.id, 'e1');
    });

    test('returns null for unknown id', () {
      final emp = container.read(teamProvider.notifier).findById('unknown');
      expect(emp, isNull);
    });

    test('returns null for empty id', () {
      final emp = container.read(teamProvider.notifier).findById('');
      expect(emp, isNull);
    });
  });

  group('Employee.initials', () {
    test('returns first character for single-word name', () {
      const emp = Employee(
        id: 'x',
        name: 'Alice',
        role: WorkerRole.helper,
        email: 'a@a.com',
        phone: '0',
        workStartHour: 8,
        workEndHour: 16,
        workingDays: {1},
      );
      expect(emp.initials, 'A');
    });

    test('returns initials of first two words', () {
      const emp = Employee(
        id: 'x',
        name: 'Alice Bob',
        role: WorkerRole.helper,
        email: 'a@a.com',
        phone: '0',
        workStartHour: 8,
        workEndHour: 16,
        workingDays: {1},
      );
      expect(emp.initials, 'AB');
    });

    test('returns initials from first two words of multi-word name', () {
      const emp = Employee(
        id: 'x',
        name: 'John Michael Smith',
        role: WorkerRole.helper,
        email: 'j@j.com',
        phone: '0',
        workStartHour: 8,
        workEndHour: 16,
        workingDays: {1},
      );
      expect(emp.initials, 'JM');
    });

    test('returns uppercase initials', () {
      const emp = Employee(
        id: 'x',
        name: 'john doe',
        role: WorkerRole.helper,
        email: 'j@j.com',
        phone: '0',
        workStartHour: 8,
        workEndHour: 16,
        workingDays: {1},
      );
      expect(emp.initials, 'JD');
    });

    test('handles abbreviated name like "Andrei D."', () {
      const emp = Employee(
        id: 'e1',
        name: 'Andrei D.',
        role: WorkerRole.helper,
        email: 'a@a.com',
        phone: '0',
        workStartHour: 8,
        workEndHour: 16,
        workingDays: {1},
      );
      expect(emp.initials, 'AD');
    });
  });

  group('Employee.copyWith', () {
    const original = Employee(
      id: 'orig',
      name: 'Original Name',
      role: WorkerRole.helper,
      email: 'orig@orig.com',
      phone: '111',
      workStartHour: 8,
      workEndHour: 17,
      workingDays: {1, 2, 3, 4, 5},
      latitude: 46.0,
      longitude: 23.0,
    );

    test('copies all fields when no overrides given', () {
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.role, original.role);
      expect(copy.email, original.email);
      expect(copy.phone, original.phone);
      expect(copy.workStartHour, original.workStartHour);
      expect(copy.workEndHour, original.workEndHour);
      expect(copy.workingDays, original.workingDays);
      expect(copy.latitude, original.latitude);
      expect(copy.longitude, original.longitude);
    });

    test('overrides name only', () {
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.role, original.role);
    });

    test('overrides workStartHour and workEndHour', () {
      final copy = original.copyWith(workStartHour: 6, workEndHour: 14);
      expect(copy.workStartHour, 6);
      expect(copy.workEndHour, 14);
      expect(copy.name, original.name);
    });

    test('overrides workingDays', () {
      final copy = original.copyWith(workingDays: {6, 7});
      expect(copy.workingDays, {6, 7});
    });

    test('preserves id on copy', () {
      final copy = original.copyWith(name: 'Changed');
      expect(copy.id, 'orig');
    });

    test('overrides coordinates', () {
      final copy = original.copyWith(latitude: 1.0, longitude: 2.0);
      expect(copy.latitude, 1.0);
      expect(copy.longitude, 2.0);
    });
  });
}
