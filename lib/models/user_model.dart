class UserModel {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String address;
  final String photoUrl;
  final String bio;
  final String role; // 'user', 'courier', 'admin'
  final String? courierStatus; // 'pending', 'approved', 'rejected'
  final String? ktp;
  final String? vehicle;
  final int isActive; // 1 = active, 0 = blocked

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.address,
    required this.photoUrl,
    required this.bio,
    this.role = 'user',
    this.courierStatus,
    this.ktp,
    this.vehicle,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'address': address,
      'photoUrl': photoUrl,
      'bio': bio,
      'role': role,
      'courierStatus': courierStatus,
      'ktp': ktp,
      'vehicle': vehicle,
      'isActive': isActive,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      courierStatus: map['courierStatus'] as String?,
      ktp: map['ktp'] as String?,
      vehicle: map['vehicle'] as String?,
      isActive: map['isActive'] as int? ?? 1,
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    String? phone,
    String? address,
    String? photoUrl,
    String? bio,
    String? role,
    String? courierStatus,
    String? ktp,
    String? vehicle,
    int? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      courierStatus: courierStatus ?? this.courierStatus,
      ktp: ktp ?? this.ktp,
      vehicle: vehicle ?? this.vehicle,
      isActive: isActive ?? this.isActive,
    );
  }
}
