import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/db_helper.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId != null) {
      final db = await DBHelper.instance.database;
      final maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (maps.isNotEmpty) {
        _currentUser = UserModel.fromMap(maps.first);
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final result = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email.trim(), password],
      );

      if (result.isNotEmpty) {
        final user = UserModel.fromMap(result.first);
        
        if (user.isActive == 0) {
          _errorMessage = 'Akun Anda telah dinonaktifkan/diblokir oleh admin';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        if (user.role == 'courier') {
          if (user.courierStatus == 'pending') {
            _errorMessage = 'Pendaftaran kurir Anda sedang menunggu persetujuan admin';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (user.courierStatus == 'rejected') {
            _errorMessage = 'Pendaftaran kurir Anda ditolak oleh admin';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }

        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', _currentUser!.id!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Email atau password salah';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    String role = 'user',
    String? ktp,
    String? vehicle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;

      // Check email uniqueness
      final existing = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email.trim()],
      );

      if (existing.isNotEmpty) {
        _errorMessage = 'Email sudah terdaftar';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = UserModel(
        name: name,
        email: email.trim(),
        password: password,
        phone: phone,
        address: address,
        photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150', // Default photo
        bio: role == 'courier' ? 'Kurir Mitra BeliBekas Bengkalis.' : 'Pengguna baru di Marketplace Jual Beli Bekas Bengkalis.',
        role: role,
        courierStatus: role == 'courier' ? 'pending' : null,
        ktp: ktp,
        vehicle: vehicle,
        isActive: 1,
      );

      final id = await db.insert('users', user.toMap());

      // If registered user is standard, automatically log them in
      if (role == 'user') {
        _currentUser = user.copyWith(id: id);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', id);

        // Parse address for addresses table
        String villagePart = 'Bengkalis Kota';
        String detailPart = address;
        if (address.contains(', Desa/Kel. ')) {
          final parts = address.split(', Desa/Kel. ');
          detailPart = parts[0];
          if (parts[1].contains(', Kec. ')) {
            villagePart = parts[1].split(', Kec. ')[0];
          } else {
            villagePart = parts[1];
          }
        }

        await db.insert('addresses', {
          'userId': id,
          'name': 'Alamat Utama',
          'village': villagePart.trim(),
          'detail': detailPart.trim(),
          'isPrimary': 1,
        });
      } else {
        // Courier registered, does not log in, needs admin approval.
        _currentUser = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mendaftar: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(
    String name,
    String phone,
    String address,
    String bio,
    String photoUrl,
  ) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
        address: address,
        bio: bio,
        photoUrl: photoUrl,
      );

      final db = await DBHelper.instance.database;
      await db.update(
        'users',
        updatedUser.toMap(),
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      // Update sellerName in existing products for this user
      await db.update(
        'products',
        {'sellerName': name},
        where: 'sellerId = ?',
        whereArgs: [_currentUser!.id],
      );

      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui profil';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    _currentUser = null;
    notifyListeners();
  }
}
