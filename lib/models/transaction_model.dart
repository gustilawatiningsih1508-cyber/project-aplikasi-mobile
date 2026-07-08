class TransactionModel {
  final int? id;
  final int productId;
  final int buyerId;
  final int sellerId;
  final double amount;
  final String paymentMethod; // e.g. 'Cash on Delivery (COD)' or 'Transfer Bank (BRI/Mandiri)'
  final String status; 
  final int? courierRequestId;
  final String? paymentProofUrl;
  final double? sellerRating;
  final String? sellerReview;
  final double? courierRating;
  final String? courierReview;
  final String createdAt;

  TransactionModel({
    this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.courierRequestId,
    this.paymentProofUrl,
    this.sellerRating,
    this.sellerReview,
    this.courierRating,
    this.courierReview,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      if (courierRequestId != null) 'courierRequestId': courierRequestId,
      'paymentProofUrl': paymentProofUrl,
      'sellerRating': sellerRating,
      'sellerReview': sellerReview,
      'courierRating': courierRating,
      'courierReview': courierReview,
      'createdAt': createdAt,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      productId: map['productId'] as int? ?? 0,
      buyerId: map['buyerId'] as int? ?? 0,
      sellerId: map['sellerId'] as int? ?? 0,
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      status: map['status'] as String? ?? 'Paid',
      courierRequestId: map['courierRequestId'] as int?,
      paymentProofUrl: map['paymentProofUrl'] as String?,
      sellerRating: (map['sellerRating'] as num?)?.toDouble(),
      sellerReview: map['sellerReview'] as String?,
      courierRating: (map['courierRating'] as num?)?.toDouble(),
      courierReview: map['courierReview'] as String?,
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  TransactionModel copyWith({
    int? id,
    int? productId,
    int? buyerId,
    int? sellerId,
    double? amount,
    String? paymentMethod,
    String? status,
    int? courierRequestId,
    String? paymentProofUrl,
    double? sellerRating,
    String? sellerReview,
    double? courierRating,
    String? courierReview,
    String? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      courierRequestId: courierRequestId ?? this.courierRequestId,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      sellerRating: sellerRating ?? this.sellerRating,
      sellerReview: sellerReview ?? this.sellerReview,
      courierRating: courierRating ?? this.courierRating,
      courierReview: courierReview ?? this.courierReview,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
