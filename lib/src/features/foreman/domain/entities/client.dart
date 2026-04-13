import 'client_enums.dart';
export 'client_enums.dart';

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
