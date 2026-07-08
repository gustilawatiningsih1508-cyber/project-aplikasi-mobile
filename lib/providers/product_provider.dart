import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/db_helper.dart';

class ProductProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;

  // Filters
  String _searchQuery = '';
  String _selectedCategory = 'Semua'; // 'Semua' (All), 'Elektronik', 'Pakaian', 'Mebel', 'Buku', 'Lainnya'
  double? _minPrice;
  double? _maxPrice;
  List<String> _selectedConditions = []; // 'Baru', 'Sangat Baik', 'Baik', 'Cukup'

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  List<String> get selectedConditions => _selectedConditions;

  ProductProvider() {
    loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'status = ?',
        whereArgs: ['Tersedia'],
        orderBy: 'id DESC',
      );

      _products = List.generate(maps.length, (i) {
        return ProductModel.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Get products based on search and filters
  List<ProductModel> get filteredProducts {
    return _products.where((product) {
      // Name Search
      if (_searchQuery.isNotEmpty &&
          !product.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Category filter
      if (_selectedCategory != 'Semua' &&
          product.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      // Min Price
      if (_minPrice != null && product.price < _minPrice!) {
        return false;
      }

      // Max Price
      if (_maxPrice != null && product.price > _maxPrice!) {
        return false;
      }

      // Condition filter
      if (_selectedConditions.isNotEmpty &&
          !_selectedConditions.contains(product.condition)) {
        return false;
      }

      return true;
    }).toList();
  }

  void setFilters({
    String? searchQuery,
    String? category,
    double? minPrice,
    double? maxPrice,
    List<String>? conditions,
  }) {
    if (searchQuery != null) _searchQuery = searchQuery;
    if (category != null) _selectedCategory = category;
    if (minPrice != null) _minPrice = minPrice;
    if (maxPrice != null) _maxPrice = maxPrice;
    if (conditions != null) _selectedConditions = conditions;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'Semua';
    _minPrice = null;
    _maxPrice = null;
    _selectedConditions = [];
    notifyListeners();
  }

  Future<bool> addProduct(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final id = await db.insert('products', product.toMap());
      _products.insert(0, product.copyWith(id: id));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding product: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProductStatus(int productId, String status) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'products',
        {'status': status},
        where: 'id = ?',
        whereArgs: [productId],
      );
      // reload lists
      await loadProducts();
    } catch (e) {
      debugPrint('Error updating product status: $e');
    }
  }

  Future<List<ProductModel>> getUserListings(int userId) async {
    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'sellerId = ?',
        whereArgs: [userId],
        orderBy: 'id DESC',
      );
      return List.generate(maps.length, (i) => ProductModel.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Error fetching user listings: $e');
      return [];
    }
  }

  Future<ProductModel?> getProductById(int id) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (result.isNotEmpty) {
        return ProductModel.fromMap(result.first);
      }
    } catch (e) {
      debugPrint('Error fetching product details: $e');
    }
    return null;
  }

  Future<bool> updateProduct(ProductModel product) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'products',
        product.toMap(),
        where: 'id = ?',
        whereArgs: [product.id],
      );
      // Update in-memory list
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int productId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  // Get count of pending orders for seller (used for badges)
  Future<int> getPendingSellerOrderCount(int sellerId) async {
    try {
      final db = await DBHelper.instance.database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM transactions WHERE sellerId = ? AND status IN ('Menunggu Konfirmasi Penjual', 'Menunggu Pembayaran')",
        [sellerId],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting pending order count: $e');
      return 0;
    }
  }
}
