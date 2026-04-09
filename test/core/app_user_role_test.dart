import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/domain/entities/app_user_role.dart';

void main() {
  group('AppUserRole', () {
    test('foreman has label "Foreman"', () {
      expect(AppUserRole.foreman.label, 'Foreman');
    });

    test('worker has label "Worker"', () {
      expect(AppUserRole.worker.label, 'Worker');
    });

    test('enum has exactly two values', () {
      expect(AppUserRole.values.length, 2);
    });

    test('values are foreman and worker', () {
      expect(AppUserRole.values, contains(AppUserRole.foreman));
      expect(AppUserRole.values, contains(AppUserRole.worker));
    });

    test('foreman and worker are distinct', () {
      expect(AppUserRole.foreman, isNot(AppUserRole.worker));
    });
  });
}
