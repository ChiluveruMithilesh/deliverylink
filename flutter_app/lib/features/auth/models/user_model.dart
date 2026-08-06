class UserModel {
  const UserModel({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.email,
  });

  final String id;
  final String role; // distributor | driver | shopkeeper | admin
  final String fullName;
  final String phone;
  final String? email;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        role: json['role'] as String,
        fullName: (json['fullName'] ?? json['full_name']) as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'fullName': fullName,
        'phone': phone,
        'email': email,
      };

  bool get isDistributor => role == 'distributor';
  bool get isDriver => role == 'driver';
  bool get isShopkeeper => role == 'shopkeeper';
  bool get isAdmin => role == 'admin';
}
