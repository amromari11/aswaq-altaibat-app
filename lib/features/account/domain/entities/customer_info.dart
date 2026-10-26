/// Who the order is for and how the driver reaches them. Phone is E.164
/// (`+9627XXXXXXXX`, see `JordanPhone.normalize`) and is not verified.
class CustomerInfo {
  const CustomerInfo({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  bool operator ==(Object other) => other is CustomerInfo && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}
