/// The signed-in foreman's own details. Their email is the login, so it is
/// shown from the session and not edited here.
class MyProfile {
  const MyProfile({this.fullName = '', this.phone = '', this.jobTitle = ''});

  final String fullName;
  final String phone;
  final String jobTitle;

  MyProfile trimmed() => MyProfile(
    fullName: fullName.trim(),
    phone: phone.trim(),
    jobTitle: jobTitle.trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is MyProfile &&
      other.fullName == fullName &&
      other.phone == phone &&
      other.jobTitle == jobTitle;

  @override
  int get hashCode => Object.hash(fullName, phone, jobTitle);
}

/// The company's details. With a backend this is one record shared by every
/// foreman of the company.
class CompanyDetails {
  const CompanyDetails({
    this.name = '',
    this.addressLine1 = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.iban = '',
    this.cui = '',
    this.vatNumber = '',
    this.regCom = '',
  });

  final String name;
  final String addressLine1;
  final String city;

  /// County.
  final String state;
  final String zipCode;
  final String iban;

  /// Romanian fiscal code.
  final String cui;
  final String vatNumber;

  /// Trade register number (Nr. Reg. Com.).
  final String regCom;

  CompanyDetails trimmed() => CompanyDetails(
    name: name.trim(),
    addressLine1: addressLine1.trim(),
    city: city.trim(),
    state: state.trim(),
    zipCode: zipCode.trim(),
    iban: iban.trim(),
    cui: cui.trim(),
    vatNumber: vatNumber.trim(),
    regCom: regCom.trim(),
  );

  List<String> get _fields => [
    name,
    addressLine1,
    city,
    state,
    zipCode,
    iban,
    cui,
    vatNumber,
    regCom,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! CompanyDetails) return false;
    final mine = _fields;
    final theirs = other._fields;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}
