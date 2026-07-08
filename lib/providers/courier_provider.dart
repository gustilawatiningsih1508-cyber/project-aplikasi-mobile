import 'dart:async';
import 'package:flutter/material.dart';
import '../models/courier_model.dart';
import '../models/transaction_model.dart';
import '../services/db_helper.dart';

class CourierProvider extends ChangeNotifier {
  List<CourierModel> _requests = [];
  bool _isLoading = false;

  List<CourierModel> get requests => _requests;
  bool get isLoading => _isLoading;

  // Bengkalis City (Kecamatan Bengkalis) valid subdistricts/villages
  final List<String> bengkalisCityVillages = [
    'Bengkalis Kota',
    'Damon',
    'Rimba Sekampung',
    'Senggoro',
    'Air Putih',
    'Kelapapati',
    'Pedekik',
    'Wonosari',
    'Sebauk',
    'Teluk Latak',
    'Kuala Alam',
    'Penampi',
    'Temeran',
    'Meskom',
  ];

  // Flat rate within Bengkalis City
  final double deliveryRate = 12000.0;

  Future<void> loadUserCourierRequests(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'courier_requests',
        where: 'buyerId = ? OR sellerId = ?',
        whereArgs: [userId, userId],
        orderBy: 'id DESC',
      );

      _requests = List.generate(maps.length, (i) {
        return CourierModel.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('Error loading courier requests: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Zone-based shipping rate calculation
  double calculateShippingFee(String sellerVillage, String buyerVillage) {
    if (sellerVillage.trim().toLowerCase() == buyerVillage.trim().toLowerCase()) {
      return 7000.0;
    }

    final zone1 = ['Bengkalis Kota', 'Damon', 'Rimba Sekampung'];
    final zone2 = ['Senggoro', 'Kelapapati', 'Wonosari', 'Kuala Alam', 'Air Putih', 'Pedekik'];

    if (zone1.contains(buyerVillage)) {
      return 10000.0;
    } else if (zone2.contains(buyerVillage)) {
      return 14000.0;
    } else {
      return 20000.0;
    }
  }

  // Create transaction and courier request together
  Future<int?> createPurchaseAndCourierRequest({
    required int productId,
    required int buyerId,
    required int sellerId,
    required double amount,
    required String paymentMethod,
    required String pickupAddress,
    required String deliveryAddress,
    required double shippingFee,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      // Start transaction block
      return await db.transaction<int?>((txn) async {
        // 1. Insert Transaction (Status starts as 'Menunggu Konfirmasi Penjual')
        final txnId = await txn.insert('transactions', {
          'productId': productId,
          'buyerId': buyerId,
          'sellerId': sellerId,
          'amount': amount + shippingFee,
          'paymentMethod': paymentMethod,
          'status': 'Menunggu Konfirmasi Penjual',
          'createdAt': now,
        });

        // 2. Insert Courier Request (Status starts as 'Menunggu Konfirmasi Penjual')
        final courierRequestId = await txn.insert('courier_requests', {
          'transactionId': txnId,
          'buyerId': buyerId,
          'sellerId': sellerId,
          'pickupAddress': pickupAddress,
          'deliveryAddress': deliveryAddress,
          'status': 'Menunggu Konfirmasi Penjual',
          'courierName': 'Mencari Kurir...',
          'price': shippingFee,
          'createdAt': now,
        });

        // 3. Update Transaction with courierRequestId
        await txn.update(
          'transactions',
          {'courierRequestId': courierRequestId},
          where: 'id = ?',
          whereArgs: [txnId],
        );

        // 4. Update Product Status to 'Pending' (Reserved)
        await txn.update(
          'products',
          {'status': 'Pending'},
          where: 'id = ?',
          whereArgs: [productId],
        );

        return txnId;
      });
    } catch (e) {
      debugPrint('Transaction error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Seller confirms order
  Future<bool> confirmOrder(int transactionId, String paymentMethod) async {
    try {
      final db = await DBHelper.instance.database;
      String nextStatus;
      
      if (paymentMethod.contains('COD')) {
        nextStatus = 'Mencari Kurir';
      } else {
        nextStatus = 'Menunggu Pembayaran';
      }

      await db.update(
        'transactions',
        {'status': nextStatus},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      await db.update(
        'courier_requests',
        {'status': nextStatus},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error confirming order: $e');
      return false;
    }
  }

  // Buyer uploads proof of payment
  Future<bool> uploadPaymentProof(int transactionId, String proofUrl) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'transactions',
        {'paymentProofUrl': proofUrl},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error uploading payment proof: $e');
      return false;
    }
  }

  // Seller confirms payment proof
  Future<bool> confirmPayment(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'transactions',
        {'status': 'Pembayaran Dikonfirmasi'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      await db.update(
        'courier_requests',
        {'status': 'Pembayaran Dikonfirmasi'},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      // Instantly advance to Mencari Kurir
      await db.update(
        'transactions',
        {'status': 'Mencari Kurir'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      await db.update(
        'courier_requests',
        {'status': 'Mencari Kurir'},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error confirming payment: $e');
      return false;
    }
  }

  // Courier accepts courier request
  Future<bool> acceptCourierRequest(int requestId, int courierId, String courierName) async {
    try {
      final db = await DBHelper.instance.database;
      
      // Update courier request status to 'Barang Diambil'
      await db.update(
        'courier_requests',
        {
          'courierId': courierId,
          'courierName': courierName,
          'status': 'Barang Diambil',
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );

      final reqResult = await db.query('courier_requests', where: 'id = ?', whereArgs: [requestId]);
      if (reqResult.isNotEmpty) {
        final txnId = reqResult.first['transactionId'] as int;
        await db.update(
          'transactions',
          {'status': 'Barang Diambil'},
          where: 'id = ?',
          whereArgs: [txnId],
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting courier request: $e');
      return false;
    }
  }

  // Courier updates delivery status
  Future<bool> updateCourierRequestStatus(int requestId, String newStatus) async {
    try {
      final db = await DBHelper.instance.database;
      
      await db.update(
        'courier_requests',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [requestId],
      );

      final reqResult = await db.query('courier_requests', where: 'id = ?', whereArgs: [requestId]);
      if (reqResult.isNotEmpty) {
        final txnId = reqResult.first['transactionId'] as int;
        await db.update(
          'transactions',
          {'status': newStatus},
          where: 'id = ?',
          whereArgs: [txnId],
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating courier status: $e');
      return false;
    }
  }

  // Buyer confirms item received
  Future<bool> confirmItemReceived(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      
      await db.update(
        'transactions',
        {'status': 'Selesai'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      await db.update(
        'courier_requests',
        {'status': 'Selesai'},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      // Update product status to 'Sold'
      final txn = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (txn.isNotEmpty) {
        final prodId = txn.first['productId'] as int;
        await db.update(
          'products',
          {'status': 'Terjual'},
          where: 'id = ?',
          whereArgs: [prodId],
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error confirming receipt: $e');
      return false;
    }
  }

  // Add ratings and reviews
  Future<bool> addRatings({
    required int transactionId,
    required double sellerRating,
    required String sellerReview,
    required double courierRating,
    required String courierReview,
  }) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'transactions',
        {
          'sellerRating': sellerRating,
          'sellerReview': sellerReview,
          'courierRating': courierRating,
          'courierReview': courierReview,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error submitting rating: $e');
      return false;
    }
  }

  // Fetch requests available for couriers (Mencari Kurir status)
  Future<List<CourierModel>> getAvailableCourierRequests() async {
    try {
      final db = await DBHelper.instance.database;
      final maps = await db.query(
        'courier_requests',
        where: 'status = ?',
        whereArgs: ['Mencari Kurir'],
        orderBy: 'id DESC',
      );
      return List.generate(maps.length, (i) => CourierModel.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error loading available requests: $e');
      return [];
    }
  }

  // Fetch active requests assigned to a courier
  Future<List<CourierModel>> getCourierActiveDeliveries(int courierId) async {
    try {
      final db = await DBHelper.instance.database;
      final maps = await db.query(
        'courier_requests',
        where: 'courierId = ? AND status IN (?, ?, ?)',
        whereArgs: [courierId, 'Barang Diambil', 'Dalam Perjalanan', 'Terkirim'],
        orderBy: 'id DESC',
      );
      return List.generate(maps.length, (i) => CourierModel.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error loading courier active deliveries: $e');
      return [];
    }
  }

  // Fetch completed requests for a courier
  Future<List<CourierModel>> getCourierHistory(int courierId) async {
    try {
      final db = await DBHelper.instance.database;
      final maps = await db.query(
        'courier_requests',
        where: 'courierId = ? AND status = ?',
        whereArgs: [courierId, 'Selesai'],
        orderBy: 'id DESC',
      );
      return List.generate(maps.length, (i) => CourierModel.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error loading courier history: $e');
      return [];
    }
  }

  // Fetch single courier request by transactionId
  Future<CourierModel?> getCourierRequestByTransactionId(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'courier_requests',
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );
      if (result.isNotEmpty) {
        return CourierModel.fromMap(result.first);
      }
    } catch (e) {
      debugPrint('Error getting courier request: $e');
    }
    return null;
  }

  // Fetch single courier request by id
  Future<CourierModel?> getCourierRequestById(int id) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'courier_requests',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result.isNotEmpty) {
        return CourierModel.fromMap(result.first);
      }
    } catch (e) {
      debugPrint('Error getting courier request: $e');
    }
    return null;
  }

  // Fetch transaction history
  Future<List<TransactionModel>> getPurchaseHistory(int buyerId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'transactions',
        where: 'buyerId = ?',
        whereArgs: [buyerId],
        orderBy: 'id DESC',
      );
      return List.generate(result.length, (i) => TransactionModel.fromMap(result[i]));
    } catch (e) {
      debugPrint('Error getting purchase history: $e');
      return [];
    }
  }

  Future<List<TransactionModel>> getSellerTransactions(int sellerId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'transactions',
        where: 'sellerId = ?',
        whereArgs: [sellerId],
        orderBy: 'id DESC',
      );
      return List.generate(result.length, (i) => TransactionModel.fromMap(result[i]));
    } catch (e) {
      debugPrint('Error getting seller transactions: $e');
      return [];
    }
  }

  // Status transitions untuk Tracking Screen (sesuai status DB BI)
  Future<void> advanceCourierStatus(int requestId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'courier_requests',
        where: 'id = ?',
        whereArgs: [requestId],
      );
      if (result.isEmpty) return;

      final currentCourier = CourierModel.fromMap(result.first);
      String nextStatus = currentCourier.status;

      // Status flow (Bahasa Indonesia sesuai DB)
      if (currentCourier.status == 'Mencari Kurir') {
        nextStatus = 'Barang Diambil';
      } else if (currentCourier.status == 'Barang Diambil') {
        nextStatus = 'Dalam Perjalanan';
      } else if (currentCourier.status == 'Dalam Perjalanan') {
        nextStatus = 'Terkirim';
      }

      if (nextStatus != currentCourier.status) {
        await db.update(
          'courier_requests',
          {'status': nextStatus},
          where: 'id = ?',
          whereArgs: [requestId],
        );

        await db.update(
          'transactions',
          {'status': nextStatus},
          where: 'id = ?',
          whereArgs: [currentCourier.transactionId],
        );

        // Refresh list
        final index = _requests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _requests[index] = _requests[index].copyWith(status: nextStatus);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error advancing courier status: $e');
    }
  }

  // Automatic scheduler to progress shipment stages for demo
  void _startAutoTrackingSimulation(int requestId) {
    // Stage 1: Dalam Perjalanan after 15s
    Timer(const Duration(seconds: 15), () async {
      await advanceCourierStatus(requestId);
      
      // Stage 2: Terkirim after another 20s
      Timer(const Duration(seconds: 20), () async {
        await advanceCourierStatus(requestId);
      });
    });
  }

  // Fetch transaction by ID
  Future<Map<String, dynamic>?> getTransactionById(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (result.isNotEmpty) return result.first;
    } catch (e) {
      debugPrint('Error getting transaction: $e');
    }
    return null;
  }

  // Seller rejects an order (reverts product status)
  Future<bool> rejectOrder(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      
      // Fetch transaction first to get productId
      final txns = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (txns.isEmpty) return false;
      final productId = txns.first['productId'] as int;

      await db.update(
        'transactions',
        {'status': 'Dibatalkan'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await db.update(
        'courier_requests',
        {'status': 'Dibatalkan'},
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );
      // Revert product to Available
      await db.update(
        'products',
        {'status': 'Tersedia'},
        where: 'id = ?',
        whereArgs: [productId],
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error rejecting order: $e');
      return false;
    }
  }
}
