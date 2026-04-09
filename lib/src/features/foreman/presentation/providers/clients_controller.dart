import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientsProvider = NotifierProvider<ClientsNotifier, List<Client>>(
  ClientsNotifier.new,
);

class ClientsNotifier extends Notifier<List<Client>> {
  @override
  List<Client> build() {
    return const [
      Client(
        id: 'c1',
        name: 'Elena Popescu',
        activeProjects: 2,
        email: 'elena.popescu@example.com',
        phone: '+40 731 100 101',
        address: 'Str. Victoriei 12, Bucuresti',
        contactPerson: 'Elena Popescu',
      ),
      Client(
        id: 'c2',
        name: 'SC BuildFast SRL',
        activeProjects: 1,
        email: 'office@buildfast.example.com',
        phone: '+40 744 222 333',
        address: 'Bd. Independentei 7, Cluj-Napoca',
        contactPerson: 'Radu Ionescu',
      ),
      Client(
        id: 'c3',
        name: 'Cafe Luna',
        activeProjects: 1,
        email: 'contact@cafeluna.example.com',
        phone: '+40 756 333 444',
        address: 'Piata Unirii 3, Timisoara',
        contactPerson: 'Ana Moldovan',
      ),
    ];
  }

  void addClient({
    required String name,
    required int activeProjects,
    required String email,
    required String phone,
    required String address,
    required String contactPerson,
  }) {
    final nextId =
        'c${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Client(
        id: nextId,
        name: name,
        activeProjects: activeProjects,
        email: email,
        phone: phone,
        address: address,
        contactPerson: contactPerson,
      ),
    ];
  }

  void updateClient({
    required String id,
    required String name,
    required int activeProjects,
    required String email,
    required String phone,
    required String address,
    required String contactPerson,
  }) {
    state = [
      for (final client in state)
        if (client.id == id)
          client.copyWith(
            name: name,
            activeProjects: activeProjects,
            email: email,
            phone: phone,
            address: address,
            contactPerson: contactPerson,
          )
        else
          client,
    ];
  }

  Client? findById(String id) {
    for (final client in state) {
      if (client.id == id) return client;
    }
    return null;
  }
}

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.activeProjects,
    required this.email,
    required this.phone,
    required this.address,
    required this.contactPerson,
  });

  final String id;
  final String name;
  final int activeProjects;
  final String email;
  final String phone;
  final String address;
  final String contactPerson;

  String get activeProjectsLabel {
    return activeProjects == 1
        ? '1 active project'
        : '$activeProjects active projects';
  }

  Client copyWith({
    String? name,
    int? activeProjects,
    String? email,
    String? phone,
    String? address,
    String? contactPerson,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      activeProjects: activeProjects ?? this.activeProjects,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}
