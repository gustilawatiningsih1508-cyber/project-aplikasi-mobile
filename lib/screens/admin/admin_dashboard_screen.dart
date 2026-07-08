import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/db_helper.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Map<String, dynamic>> _pendingCouriers = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _transactions = [];
  
  // Reports metrics
  double _totalOmset = 0;
  double _totalCourierFee = 0;
  int _activeUsersCount = 0;
  int _successDeliveriesCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);

    try {
      final db = await DBHelper.instance.database;

      final couriers = await db.query('users', where: 'role = ? AND courierStatus = ?', whereArgs: ['courier', 'pending']);
      final allUsers = await db.query('users', where: 'role != ?', whereArgs: ['admin'], orderBy: 'role DESC, name ASC');
      final allProducts = await db.query('products', orderBy: 'id DESC');
      final allTxns = await db.query('transactions', orderBy: 'id DESC');

      final omsetRes = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE status = 'Selesai'");
      final courierRes = await db.rawQuery("SELECT SUM(price) as total FROM courier_requests WHERE status = 'Selesai'");
      final usersCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE isActive = 1 AND role = 'user'");
      final deliveriesCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM courier_requests WHERE status = 'Selesai'");

      if (mounted) {
        setState(() {
          _pendingCouriers = couriers;
          _users = allUsers;
          _products = allProducts;
          _transactions = allTxns;

          _totalOmset = (omsetRes.first['total'] as num? ?? 0.0).toDouble();
          _totalCourierFee = (courierRes.first['total'] as num? ?? 0.0).toDouble();
          _activeUsersCount = usersCountRes.first['count'] as int? ?? 0;
          _successDeliveriesCount = deliveriesCountRes.first['count'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveCourier(int userId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update('users', {'courierStatus': 'approved'}, where: 'id = ?', whereArgs: [userId]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kurir berhasil disetujui!', style: GoogleFonts.poppins()), backgroundColor: AppTheme.successColor));
        _loadAllAdminData();
      }
    } catch (e) {
      debugPrint('Error approving courier: $e');
    }
  }

  Future<void> _rejectCourier(int userId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update('users', {'courierStatus': 'rejected'}, where: 'id = ?', whereArgs: [userId]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pendaftaran kurir ditolak.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.errorColor));
        _loadAllAdminData();
      }
    } catch (e) {
      debugPrint('Error rejecting courier: $e');
    }
  }

  Future<void> _toggleUserStatus(int userId, int currentActive) async {
    try {
      final db = await DBHelper.instance.database;
      final newStatus = currentActive == 1 ? 0 : 1;
      await db.update('users', {'isActive': newStatus}, where: 'id = ?', whereArgs: [userId]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 0 ? 'User berhasil diblokir!' : 'User berhasil diaktifkan kembali.', style: GoogleFonts.poppins()),
          backgroundColor: newStatus == 0 ? AppTheme.warningColor : AppTheme.successColor,
        ));
        _loadAllAdminData();
      }
    } catch (e) {
      debugPrint('Error toggling user status: $e');
    }
  }

  Future<void> _deleteProduct(int productId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.delete('products', where: 'id = ?', whereArgs: [productId]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produk berhasil dihapus.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.errorColor));
        _loadAllAdminData();
      }
    } catch (e) {
      debugPrint('Error deleting product: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Admin Panel', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAllAdminData),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.verified_user_rounded), text: 'Approve Kurir'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Kelola User'),
            Tab(icon: Icon(Icons.shopping_bag_rounded), text: 'Moderasi'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transaksi'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Laporan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCourierApprovalsTab(),
                _buildManageUsersTab(),
                _buildManageProductsTab(),
                _buildTransactionsTab(currencyFormatter),
                _buildReportsTab(currencyFormatter),
              ],
            ),
    );
  }

  Widget _buildCourierApprovalsTab() {
    if (_pendingCouriers.isEmpty) {
      return _buildEmptyState(Icons.check_circle_outline_rounded, 'Tidak ada pengajuan kurir', 'Semua pengajuan telah diproses.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingCouriers.length,
      itemBuilder: (context, index) {
        final courier = _pendingCouriers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundImage: AssetImage(courier['photoUrl'] ?? 'assets/images/avatar.png'), radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(courier['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(courier['email'], style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildDetailRow(Icons.phone_android_rounded, 'WhatsApp', courier['phone']),
              _buildDetailRow(Icons.badge_rounded, 'NIK KTP', courier['ktp'] ?? '-'),
              _buildDetailRow(Icons.two_wheeler_rounded, 'Kendaraan', courier['vehicle'] ?? '-'),
              _buildDetailRow(Icons.location_on_rounded, 'Alamat', courier['address']),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectCourier(courier['id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      child: Text('Tolak', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveCourier(courier['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                      child: Text('Setujui', style: GoogleFonts.poppins()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManageUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final roleLabel = user['role'] == 'courier' ? 'KURIR' : 'USER';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(backgroundImage: AssetImage(user['photoUrl'] ?? 'assets/images/avatar.png')),
            title: Row(
              children: [
                Expanded(child: Text(user['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user['role'] == 'courier' ? AppTheme.accentColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleLabel,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: user['role'] == 'courier' ? AppTheme.primaryColor : AppTheme.successColor),
                  ),
                ),
              ],
            ),
            subtitle: Text(user['email'], style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: Switch(
              value: user['isActive'] == 1,
              activeColor: AppTheme.primaryColor,
              onChanged: (val) => _toggleUserStatus(user['id'], user['isActive']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManageProductsTab() {
    if (_products.isEmpty) return _buildEmptyState(Icons.inventory_2_rounded, 'Tidak ada produk', 'Belum ada produk dipasang.');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                color: AppTheme.lightBlue,
                child: const Icon(Icons.image_rounded, color: AppTheme.primaryColor, size: 32), // Placeholder for image
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Kategori: ${product['category']}', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11)),
                    Text('Penjual: ${product['sellerName']}', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11)),
                    Text('Status: ${product['status']}', style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: AppTheme.errorColor),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Hapus Produk?', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                      content: Text('Apakah Anda yakin ingin menghapus produk ini?', style: GoogleFonts.poppins()),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey))),
                        TextButton(onPressed: () { Navigator.pop(context); _deleteProduct(product['id']); }, child: Text('Hapus', style: GoogleFonts.poppins(color: AppTheme.errorColor, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab(NumberFormat fmt) {
    if (_transactions.isEmpty) return _buildEmptyState(Icons.receipt_long_rounded, 'Belum ada transaksi', 'Belum ada transaksi tercatat.');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final txn = _transactions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('INV-TXN-${1000 + txn['id']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(8)),
                    child: Text(txn['status'], style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
              _buildDetailRow(Icons.person_rounded, 'Pembeli ID', txn['buyerId'].toString()),
              _buildDetailRow(Icons.store_rounded, 'Penjual ID', txn['sellerId'].toString()),
              _buildDetailRow(Icons.payment_rounded, 'Metode', txn['paymentMethod']),
              _buildDetailRow(Icons.payments_rounded, 'Tagihan', fmt.format(txn['amount'])),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsTab(NumberFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildReportCard('Total Omset', fmt.format(_totalOmset), Icons.monetization_on_rounded, AppTheme.successColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildReportCard('Fee Kurir', fmt.format(_totalCourierFee), Icons.local_shipping_rounded, AppTheme.accentColor)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildReportCard('User Aktif', '$_activeUsersCount', Icons.people_alt_rounded, Colors.purple)),
              const SizedBox(width: 16),
              Expanded(child: _buildReportCard('Paket Selesai', '$_successDeliveriesCount', Icons.done_all_rounded, AppTheme.warningColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary)),
          ),
          const Text(': '),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(subtitle, style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
