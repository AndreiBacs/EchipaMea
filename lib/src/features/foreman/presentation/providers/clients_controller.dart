import 'package:flutter_riverpod/flutter_riverpod.dart';

final clientsProvider = NotifierProvider<ClientsNotifier, List<Client>>(
  ClientsNotifier.new,
);

class ClientsNotifier extends Notifier<List<Client>> {
  @override
  List<Client> build() {
    return const [
      Client(id: 'c1', name: 'Elena Popescu', activeProjects: 2),
      Client(id: 'c2', name: 'SC BuildFast SRL', activeProjects: 1),
      Client(id: 'c3', name: 'Cafe Luna', activeProjects: 1),
    ];
  }

  void addClient({required String name, required int activeProjects}) {
    final nextId =
        'c${state.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Client(id: nextId, name: name, activeProjects: activeProjects),
    ];
  }

  void updateClient({
    required String id,
    required String name,
    required int activeProjects,
  }) {
    state = [
      for (final client in state)
        if (client.id == id)
          client.copyWith(name: name, activeProjects: activeProjects)
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
  });

  final String id;
  final String name;
  final int activeProjects;

  String get activeProjectsLabel {
    return activeProjects == 1
        ? '1 active project'
        : '$activeProjects active projects';
  }

  Client copyWith({String? name, int? activeProjects}) {
    return Client(
      id: id,
      name: name ?? this.name,
      activeProjects: activeProjects ?? this.activeProjects,
    );
  }
}
