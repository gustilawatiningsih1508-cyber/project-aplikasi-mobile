class AddressModel {
  final int? id;
  final int userId;
  final String name; // e.g. "Rumah", "Kantor"
  final String village;
  final String detail;
  final int isPrimary; // 1 = true, 0 = false

  AddressModel({
    this.id,
    required this.userId,
    required this.name,
    required this.village,
    required this.detail,
    this.isPrimary = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'name': name,
      'village': village,
      'detail': detail,
      'isPrimary': isPrimary,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] as int?,
      userId: map['userId'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      village: map['village'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      isPrimary: map['isPrimary'] as int? ?? 0,
    );
  }

  AddressModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? village,
    String? detail,
    int? isPrimary,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      village: village ?? this.village,
      detail: detail ?? this.detail,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
