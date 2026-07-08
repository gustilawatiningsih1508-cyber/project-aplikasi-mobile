import 'dart:convert';

class ProductModel {
  final int? id;
  final int sellerId;
  final String sellerName;
  final String name;
  final double price;
  final String description;
  final String category;
  final List<String> imageUrls;
  final String condition; // e.g., 'Baru' (New), 'Sangat Baik' (Like New), 'Baik' (Good), 'Cukup' (Fair)
  final String status; // 'Tersedia', 'Dalam Proses', 'Terjual'
  final String createdAt;

  ProductModel({
    this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrls,
    required this.condition,
    required this.status,
    required this.createdAt,
  });

  // Backward-compat getter: returns first image or empty string
  String get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'imageUrls': jsonEncode(imageUrls),
      'condition': condition,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedImageUrls = [];
    try {
      if (map['imageUrls'] != null) {
        final decoded = jsonDecode(map['imageUrls'] as String);
        if (decoded is List) {
          parsedImageUrls = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      // Fallback if not valid JSON
      if (map['imageUrls'] != null && map['imageUrls'].toString().isNotEmpty) {
        parsedImageUrls = [map['imageUrls'].toString()];
      }
    }
    
    return ProductModel(
      id: map['id'] as int?,
      sellerId: map['sellerId'] as int? ?? 0,
      sellerName: map['sellerName'] as String? ?? 'Penjual',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num? ?? 0.0).toDouble(),
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Lainnya',
      imageUrls: parsedImageUrls,
      condition: map['condition'] as String? ?? 'Baik',
      status: map['status'] as String? ?? 'Tersedia',
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  ProductModel copyWith({
    int? id,
    int? sellerId,
    String? sellerName,
    String? name,
    double? price,
    String? description,
    String? category,
    List<String>? imageUrls,
    String? condition,
    String? status,
    String? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

