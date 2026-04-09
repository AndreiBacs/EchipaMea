import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/features/foreman/presentation/providers/clients_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('ClientsNotifier initial state', () {
    test('starts with 3 demo clients', () {
      final clients = container.read(clientsProvider);
      expect(clients.length, 3);
    });

    test('first demo client has id c1', () {
      final clients = container.read(clientsProvider);
      expect(clients.first.id, 'c1');
    });

    test('demo clients have required fields populated', () {
      for (final client in container.read(clientsProvider)) {
        expect(client.id, isNotEmpty);
        expect(client.name, isNotEmpty);
        expect(client.email, isNotEmpty);
        expect(client.phone, isNotEmpty);
        expect(client.address, isNotEmpty);
        expect(client.contactPerson, isNotEmpty);
      }
    });
  });

  group('ClientsNotifier.addClient', () {
    test('increases client count by one', () {
      container.read(clientsProvider.notifier).addClient(
            name: 'New Corp',
            activeProjects: 2,
            email: 'new@corp.com',
            phone: '+40 700 000 001',
            address: 'Str. Test 1',
            contactPerson: 'Ion Pop',
          );
      expect(container.read(clientsProvider).length, 4);
    });

    test('added client is appended to the end', () {
      container.read(clientsProvider.notifier).addClient(
            name: 'Appended Corp',
            activeProjects: 0,
            email: 'a@b.com',
            phone: '0700',
            address: 'Addr',
            contactPerson: 'Contact',
          );
      final clients = container.read(clientsProvider);
      expect(clients.last.name, 'Appended Corp');
    });

    test('added client has all fields set correctly', () {
      container.read(clientsProvider.notifier).addClient(
            name: 'Field Test',
            activeProjects: 5,
            email: 'ft@example.com',
            phone: '+40 700 999 888',
            address: 'Bd. Test 99',
            contactPerson: 'Maria D.',
          );
      final added = container.read(clientsProvider).last;
      expect(added.name, 'Field Test');
      expect(added.activeProjects, 5);
      expect(added.email, 'ft@example.com');
      expect(added.phone, '+40 700 999 888');
      expect(added.address, 'Bd. Test 99');
      expect(added.contactPerson, 'Maria D.');
    });

    test('generated id is unique for successive adds', () {
      container.read(clientsProvider.notifier).addClient(
            name: 'A',
            activeProjects: 0,
            email: 'a@a.com',
            phone: '0',
            address: 'A',
            contactPerson: 'A',
          );
      container.read(clientsProvider.notifier).addClient(
            name: 'B',
            activeProjects: 0,
            email: 'b@b.com',
            phone: '0',
            address: 'B',
            contactPerson: 'B',
          );
      final clients = container.read(clientsProvider);
      final ids = clients.map((c) => c.id).toSet();
      expect(ids.length, clients.length);
    });
  });

  group('ClientsNotifier.updateClient', () {
    test('updates name for existing client', () {
      container.read(clientsProvider.notifier).updateClient(
            id: 'c1',
            name: 'Updated Name',
            activeProjects: 2,
            email: 'elena.popescu@example.com',
            phone: '+40 731 100 101',
            address: 'Str. Victoriei 12, Bucuresti',
            contactPerson: 'Elena Popescu',
          );
      final updated = container
          .read(clientsProvider)
          .firstWhere((c) => c.id == 'c1');
      expect(updated.name, 'Updated Name');
    });

    test('updates activeProjects for existing client', () {
      container.read(clientsProvider.notifier).updateClient(
            id: 'c2',
            name: 'SC BuildFast SRL',
            activeProjects: 10,
            email: 'office@buildfast.example.com',
            phone: '+40 744 222 333',
            address: 'Bd. Independentei 7, Cluj-Napoca',
            contactPerson: 'Radu Ionescu',
          );
      final updated = container
          .read(clientsProvider)
          .firstWhere((c) => c.id == 'c2');
      expect(updated.activeProjects, 10);
    });

    test('does not change total count on update', () {
      final before = container.read(clientsProvider).length;
      container.read(clientsProvider.notifier).updateClient(
            id: 'c1',
            name: 'X',
            activeProjects: 0,
            email: 'x@x.com',
            phone: '0',
            address: 'X',
            contactPerson: 'X',
          );
      expect(container.read(clientsProvider).length, before);
    });

    test('does not affect other clients when updating one', () {
      container.read(clientsProvider.notifier).updateClient(
            id: 'c1',
            name: 'Changed',
            activeProjects: 0,
            email: 'e@e.com',
            phone: '0',
            address: 'A',
            contactPerson: 'A',
          );
      final c2 = container
          .read(clientsProvider)
          .firstWhere((c) => c.id == 'c2');
      expect(c2.name, 'SC BuildFast SRL');
    });

    test('unknown id does not change state', () {
      final before = container.read(clientsProvider).map((c) => c.name).toList();
      container.read(clientsProvider.notifier).updateClient(
            id: 'nonexistent',
            name: 'Ghost',
            activeProjects: 0,
            email: 'g@g.com',
            phone: '0',
            address: 'G',
            contactPerson: 'G',
          );
      final after = container.read(clientsProvider).map((c) => c.name).toList();
      expect(after, before);
    });
  });

  group('ClientsNotifier.findById', () {
    test('returns correct client for valid id', () {
      final client = container.read(clientsProvider.notifier).findById('c1');
      expect(client, isNotNull);
      expect(client!.id, 'c1');
    });

    test('returns null for unknown id', () {
      final client =
          container.read(clientsProvider.notifier).findById('unknown');
      expect(client, isNull);
    });

    test('returns null for empty id', () {
      final client = container.read(clientsProvider.notifier).findById('');
      expect(client, isNull);
    });
  });

  group('Client.activeProjectsLabel', () {
    const baseClient = Client(
      id: 'x',
      name: 'X',
      activeProjects: 0,
      email: 'x@x.com',
      phone: '0',
      address: 'A',
      contactPerson: 'A',
    );

    test('singular for 1 active project', () {
      const client = Client(
        id: 'x',
        name: 'X',
        activeProjects: 1,
        email: 'x@x.com',
        phone: '0',
        address: 'A',
        contactPerson: 'A',
      );
      expect(client.activeProjectsLabel, '1 active project');
    });

    test('plural for 0 active projects', () {
      expect(baseClient.activeProjectsLabel, '0 active projects');
    });

    test('plural for 2 active projects', () {
      const client = Client(
        id: 'x',
        name: 'X',
        activeProjects: 2,
        email: 'x@x.com',
        phone: '0',
        address: 'A',
        contactPerson: 'A',
      );
      expect(client.activeProjectsLabel, '2 active projects');
    });

    test('plural for more than 2 active projects', () {
      const client = Client(
        id: 'x',
        name: 'X',
        activeProjects: 10,
        email: 'x@x.com',
        phone: '0',
        address: 'A',
        contactPerson: 'A',
      );
      expect(client.activeProjectsLabel, '10 active projects');
    });
  });

  group('Client.copyWith', () {
    const original = Client(
      id: 'orig',
      name: 'Original',
      activeProjects: 1,
      email: 'o@o.com',
      phone: '111',
      address: 'Orig Addr',
      contactPerson: 'Orig Contact',
    );

    test('copies all fields when no overrides given', () {
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.activeProjects, original.activeProjects);
      expect(copy.email, original.email);
      expect(copy.phone, original.phone);
      expect(copy.address, original.address);
      expect(copy.contactPerson, original.contactPerson);
    });

    test('overrides name only', () {
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.email, original.email);
    });

    test('overrides activeProjects only', () {
      final copy = original.copyWith(activeProjects: 99);
      expect(copy.activeProjects, 99);
      expect(copy.name, original.name);
    });

    test('preserves id on copy', () {
      final copy = original.copyWith(name: 'Changed');
      expect(copy.id, 'orig');
    });
  });
}
