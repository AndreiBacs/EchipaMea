import '../../../core/network/api_client.dart';
import '../domain/entities/client.dart';

Client clientFromJson(Json json) => Client(
  id: json['id'] as String,
  name: json['name'] as String,
  activeProjects: (json['activeProjects'] as num?)?.toInt() ?? 0,
  type: ClientType.values.asNameMap()[json['type']] ?? ClientType.individual,
  status:
      ClientStatus.values.asNameMap()[json['status']] ?? ClientStatus.active,
  preferredContactMethod:
      ClientContactMethod.values.asNameMap()[json['preferredContactMethod']] ??
      ClientContactMethod.phone,
  notes: json['notes'] as String? ?? '',
  email: json['email'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  addressLine1: json['addressLine1'] as String? ?? '',
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  zipCode: json['zipCode'] as String? ?? '',
  contactPerson: json['contactPerson'] as String? ?? '',
);

/// The editable fields, for both create and update. `activeProjects` is left
/// out: the server derives it from the client's projects.
Json clientToJson(Client client) => {
  'name': client.name,
  'type': client.type.name,
  'status': client.status.name,
  'preferredContactMethod': client.preferredContactMethod.name,
  'notes': client.notes,
  'email': client.email,
  'phone': client.phone,
  'addressLine1': client.addressLine1,
  'city': client.city,
  'state': client.state,
  'zipCode': client.zipCode,
  'contactPerson': client.contactPerson,
};
