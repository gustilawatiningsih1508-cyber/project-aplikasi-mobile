class CourierModel {
  final int? id;
  final int transactionId;
  final int buyerId;
  final int sellerId;
  final String pickupAddress;
  final String deliveryAddress;
  final String status; // 'Pending Pickup', 'Picked Up', 'In Transit', 'Delivered'
  final String courierName;
  final int? courierId;
  final double price;
  final String createdAt;

  CourierModel({
    this.id,
    required this.transactionId,
    required this.buyerId,
    required this.sellerId,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.status,
    required this.courierName,
    this.courierId,
    required this.price,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transactionId': transactionId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'status': status,
      'courierName': courierName,
      if (courierId != null) 'courierId': courierId,
      'price': price,
      'createdAt': createdAt,
    };
  }

  factory CourierModel.fromMap(Map<String, dynamic> map) {
    return CourierModel(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int? ?? 0,
      buyerId: map['buyerId'] as int? ?? 0,
      sellerId: map['sellerId'] as int? ?? 0,
      pickupAddress: map['pickupAddress'] as String? ?? '',
      deliveryAddress: map['deliveryAddress'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending Pickup',
      courierName: map['courierName'] as String? ?? 'Bengkalis Express Courier',
      courierId: map['courierId'] as int?,
      price: (map['price'] as num? ?? 0.0).toDouble(),
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  CourierModel copyWith({
    int? id,
    int? transactionId,
    int? buyerId,
    int? sellerId,
    String? pickupAddress,
    String? deliveryAddress,
    String? status,
    String? courierName,
    int? courierId,
    double? price,
    String? createdAt,
  }) {
    return CourierModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      courierName: courierName ?? this.courierName,
      courierId: courierId ?? this.courierId,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
