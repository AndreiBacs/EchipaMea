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
