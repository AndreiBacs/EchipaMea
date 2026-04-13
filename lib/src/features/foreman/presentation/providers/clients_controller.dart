import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/client.dart';
export '../../domain/entities/client.dart';

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
  }

  void addClient({
    required String name,
    required int activeProjects,
    required ClientType type,
    required ClientStatus status,
    required ClientContactMethod preferredContactMethod,
    required String notes,
    required String email,
    required String phone,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
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
        type: type,
        status: status,
        preferredContactMethod: preferredContactMethod,
        notes: notes,
        email: email,
        phone: phone,
        addressLine1: addressLine1,
        city: city,
        state: stateProvince,
        zipCode: zipCode,
        contactPerson: contactPerson,
      ),
    ];
  }

  void updateClient({
    required String id,
    required String name,
    required int activeProjects,
    required ClientType type,
    required ClientStatus status,
    required ClientContactMethod preferredContactMethod,
    required String notes,
    required String email,
    required String phone,
    required String addressLine1,
    required String city,
    required String stateProvince,
    required String zipCode,
    required String contactPerson,
  }) {
    state = [
      for (final client in state)
        if (client.id == id)
          client.copyWith(
            name: name,
            activeProjects: activeProjects,
            type: type,
            status: status,
            preferredContactMethod: preferredContactMethod,
            notes: notes,
            email: email,
            phone: phone,
            addressLine1: addressLine1,
            city: city,
            state: stateProvince,
            zipCode: zipCode,
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

