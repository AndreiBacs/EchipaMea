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

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.activeProjects,
    required this.type,
    required this.status,
    required this.preferredContactMethod,
    required this.notes,
    required this.email,
    required this.phone,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.contactPerson,
  });

  final String id;
  final String name;
  final int activeProjects;
  final ClientType type;
  final ClientStatus status;
  final ClientContactMethod preferredContactMethod;
  final String notes;
  final String email;
  final String phone;
  final String addressLine1;
  final String city;
  final String state;
  final String zipCode;
  final String contactPerson;

  String get fullAddress => '$addressLine1, $city, $state, $zipCode';

  String get activeProjectsLabel {
    return activeProjects == 1
        ? '1 active project'
        : '$activeProjects active projects';
  }

  Client copyWith({
    String? name,
    int? activeProjects,
    ClientType? type,
    ClientStatus? status,
    ClientContactMethod? preferredContactMethod,
    String? notes,
    String? email,
    String? phone,
    String? addressLine1,
    String? city,
    String? state,
    String? zipCode,
    String? contactPerson,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      activeProjects: activeProjects ?? this.activeProjects,
      type: type ?? this.type,
      status: status ?? this.status,
      preferredContactMethod:
          preferredContactMethod ?? this.preferredContactMethod,
      notes: notes ?? this.notes,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }
}

enum ClientType {
  individual(label: 'Individual'),
  company(label: 'Company'),
  publicInstitution(label: 'Public Institution');

  const ClientType({required this.label});
  final String label;
}

enum ClientStatus {
  active(label: 'Active'),
  inactive(label: 'Inactive'),
  blocked(label: 'Blocked');

  const ClientStatus({required this.label});
  final String label;
}

enum ClientContactMethod {
  phone(label: 'Phone'),
  email(label: 'Email'),
  whatsApp(label: 'WhatsApp');

  const ClientContactMethod({required this.label});
  final String label;
}
