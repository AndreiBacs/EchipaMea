import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/config/app_env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/client.dart';
import 'client_json.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => AppEnv.hasBackend
      ? ApiClientsRepository(ref.watch(foremanApiProvider))
      : InMemoryClientsRepository(),
);

abstract interface class ClientsRepository {
  Future<List<Client>> list();

  /// Saves a new client; [draft]'s id is ignored and the stored one returned.
  Future<Client> create(Client draft);

  Future<Client> update(Client client);
}

class ApiClientsRepository implements ClientsRepository {
  ApiClientsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Client>> list() async => [
    for (final json in await _api.getAllPages('/clients')) clientFromJson(json),
  ];

  @override
  Future<Client> create(Client draft) async =>
      clientFromJson(await _api.post('/clients', body: clientToJson(draft)));

  @override
  Future<Client> update(Client client) async => clientFromJson(
    await _api.patch(
      '/clients/${Uri.encodeComponent(client.id)}',
      body: clientToJson(client),
    ),
  );
}

/// Mock mode: the demo clients, kept for as long as the app runs.
class InMemoryClientsRepository implements ClientsRepository {
  final _clients = [..._demoClients];

  @override
  Future<List<Client>> list() async => List.unmodifiable(_clients);

  @override
  Future<Client> create(Client draft) async {
    final created = draft.copyWith(
      id: 'c${_clients.length + 1}_${DateTime.now().millisecondsSinceEpoch}',
    );
    _clients.add(created);
    return created;
  }

  @override
  Future<Client> update(Client client) async {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index < 0) throw const ApiException(status: 404, code: 'NOT_FOUND');
    _clients[index] = client;
    return client;
  }
}

const _demoClients = [
  Client(
    id: 'c1',
    name: 'Elena Popescu',
    activeProjects: 2,
    type: ClientType.individual,
    status: ClientStatus.active,
    preferredContactMethod: ClientContactMethod.phone,
    notes: 'Prefers phone calls in the morning.',
    email: 'elena.popescu@example.com',
    phone: '+40 731 100 101',
    addressLine1: 'Str. Victoriei 12',
    city: 'Bucuresti',
    state: 'Bucuresti',
    zipCode: '010072',
    contactPerson: 'Elena Popescu',
  ),
  Client(
    id: 'c2',
    name: 'SC BuildFast SRL',
    activeProjects: 1,
    type: ClientType.company,
    status: ClientStatus.active,
    preferredContactMethod: ClientContactMethod.email,
    notes: 'Invoices must include purchase order reference.',
    email: 'office@buildfast.example.com',
    phone: '+40 744 222 333',
    addressLine1: 'Bd. Independentei 7',
    city: 'Cluj-Napoca',
    state: 'Cluj',
    zipCode: '400015',
    contactPerson: 'Radu Ionescu',
  ),
  Client(
    id: 'c3',
    name: 'Cafe Luna',
    activeProjects: 1,
    type: ClientType.company,
    status: ClientStatus.active,
    preferredContactMethod: ClientContactMethod.whatsApp,
    notes: '',
    email: 'contact@cafeluna.example.com',
    phone: '+40 756 333 444',
    addressLine1: 'Piata Unirii 3',
    city: 'Timisoara',
    state: 'Timis',
    zipCode: '300085',
    contactPerson: 'Ana Moldovan',
  ),
];
