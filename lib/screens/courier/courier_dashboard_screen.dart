import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/courier_model.dart';
import '../../models/product_model.dart';
import '../../services/db_helper.dart';
import '../auth/login_screen.dart';

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<CourierModel> _availableRequests = [];
  List<CourierModel> _activeDeliveries = [];
  List<CourierModel> _completedDeliveries = [];
  
  double _totalEarnings = 0;
  bool _isLoading = true;
  final List<int> _ignoredRequestIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourierData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourierData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);

    if (!auth.isAuthenticated) return;
    final courierId = auth.currentUser!.id!;

    try {
      final available = await courierProv.getAvailableCourierRequests();
      final active = await courierProv.getCourierActiveDeliveries(courierId);
      final completed = await courierProv.getCourierHistory(courierId);

      final filteredAvailable = available.where((r) => !_ignoredRequestIds.contains(r.id)).toList();
      double earnings = completed.fold(0, (sum, delivery) => sum + delivery.price);

      if (mounted) {
        setState(() {
          _availableRequests = filteredAvailable;
          _activeDeliveries = active;
          _completedDeliveries = completed;
          _totalEarnings = earnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading courier dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptOrder(int requestId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final courier = auth.currentUser!;
    final success = await courierProv.acceptCourierRequest(requestId, courier.id!, courier.name);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Orderan berhasil diambil!', style: GoogleFonts.poppins()), backgroundColor: AppTheme.successColor));
      _loadCourierData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil orderan.', style: GoogleFonts.poppins()), backgroundColor: AppTheme.errorColor));
    }
  }

  void _ignoreOrder(int requestId) {
    setState(() {
      _ignoredRequestIds.add(requestId);
      _availableRequests.removeWhere((r) => r.id == requestId);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Orderan diabaikan.', style: GoogleFonts.poppins()), duration: const Duration(seconds: 1)));
  }

  Future<void> _updateDeliveryStatus(int requestId, String currentStatus) async {
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    String nextStatus = currentStatus == 'Barang Diambil' ? 'Dalam Perjalanan' : (currentStatus == 'Dalam Perjalanan' ? 'Terkirim' : currentStatus);

    if (nextStatus == currentStatus) return;

    final success = await courierProv.updateCourierRequestStatus(requestId, nextStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status diperbarui: $nextStatus', style: GoogleFonts.poppins()), backgroundColor: AppTheme.primaryColor));
      _loadCourierData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Panel Kurir', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadCourierData),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_rounded), text: 'Order Masuk'),
            Tab(icon: Icon(Icons.directions_run_rounded), text: 'Sedang Aktif'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Riwayat'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'Pendapatan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIncomingOrdersTab(fmt),
                _buildActiveDeliveriesTab(fmt),
                _buildHistoryTab(fmt),
                _buildEarningsTab(fmt),
              ],
            ),
    );
  }

  Widget _buildIncomingOrdersTab(NumberFormat fmt) {
    if (_availableRequests.isEmpty) return _buildEmptyState(Icons.inbox_rounded, 'Belum ada orderan', 'Belum ada pesanan masuk di wilayah Anda.');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRequests.length,
      itemBuilder: (context, index) {
        final req = _availableRequests[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchTxnAndProduct(req.transactionId),
          builder: (context, snapshot) {
            final product = snapshot.data?['product'] as ProductModel?;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BKG-REG-${1000 + req.id!}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                      Text('Ongkir: ${fmt.format(req.price)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.successColor)),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  Text(product?.name ?? 'Memuat...', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildAddressRow(Icons.storefront_rounded, 'Pickup (Penjual)', req.pickupAddress),
                  const SizedBox(height: 8),
                  _buildAddressRow(Icons.location_on_rounded, 'Tujuan (Pembeli)', req.deliveryAddress),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _ignoreOrder(req.id!),
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor, side: const BorderSide(color: AppTheme.errorColor)),
                          child: Text('Tolak', style: GoogleFonts.poppins()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOrder(req.id!),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                          child: Text('Terima', style: GoogleFonts.poppins()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveDeliveriesTab(NumberFormat fmt) {
    if (_activeDeliveries.isEmpty) return _buildEmptyState(Icons.motorcycle_rounded, 'Tidak ada yang aktif', 'Ambil orderan dari tab Order Masuk.');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeDeliveries.length,
      itemBuilder: (context, index) {
        final req = _activeDeliveries[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchTxnAndProduct(req.transactionId),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final product = data?['product'] as ProductModel?;
            final txn = data?['txn'] as Map<String, dynamic>?;
            final totalToCollect = (txn?['amount'] as num? ?? 0.0).toDouble();
            final isCOD = txn?['paymentMethod']?.toString().contains('COD') ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.cardShadow),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('BKG-REG-${1000 + req.id!}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.lightBlue, borderRadius: BorderRadius.circular(8)),
                        child: Text(req.status, style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  Text(product?.name ?? 'Memuat...', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildAddressRow(Icons.storefront_rounded, 'Pickup', req.pickupAddress),
                  const SizedBox(height: 8),
                  _buildAddressRow(Icons.location_on_rounded, 'Tujuan', req.deliveryAddress),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isCOD ? 'METODE COD' : 'TRANSFER', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: isCOD ? AppTheme.warningColor : AppTheme.primaryColor, fontSize: 12)),
                      if (isCOD) Text('Kolek: ${fmt.format(totalToCollect)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.errorColor, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (req.status == 'Barang Diambil')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _updateDeliveryStatus(req.id!, req.status),
                        child: Text('Mulai Perjalanan', style: GoogleFonts.poppins()),
                      ),
                    )
                  else if (req.status == 'Dalam Perjalanan')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _updateDeliveryStatus(req.id!, req.status),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                        child: Text('Konfirmasi Selesai Antar', style: GoogleFonts.poppins()),
                      ),
                    )
                  else if (req.status == 'Terkirim')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warningColor)),
                      child: Text(
                        'Menunggu konfirmasi pembeli di aplikasi.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab(NumberFormat fmt) {
    if (_completedDeliveries.isEmpty) return _buildEmptyState(Icons.history_rounded, 'Belum ada riwayat', 'Pengantaran sukses akan muncul di sini.');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedDeliveries.length,
      itemBuilder: (context, index) {
        final req = _completedDeliveries[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchTxnAndProduct(req.transactionId),
          builder: (context, snapshot) {
            final product = snapshot.data?['product'] as ProductModel?;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
              child: ListTile(
                title: Text(product?.name ?? 'Memuat...', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tujuan: ${req.deliveryAddress.split(', Desa/Kel.')[0]}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(req.createdAt.substring(0, 16).replaceFirst('T', ' '), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                trailing: Text(fmt.format(req.price), style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.successColor, fontSize: 14)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEarningsTab(NumberFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppTheme.deepBlueGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text('PENDAPATAN ANDA', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(fmt.format(_totalEarnings), style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('Dari ${_completedDeliveries.length} Pengantaran Sukses', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Informasi Dompet Mitra', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          _buildWalletDetailCard(Icons.payments_rounded, 'Metode Penarikan', 'Penarikan saldo dapat dilakukan secara tunai di Kantor BeliBekas atau Transfer Bank.'),
          _buildWalletDetailCard(Icons.info_outline_rounded, 'Ketentuan Tarif', 'Pendapatan kurir diterima 100% tanpa potongan. Tarif dihitung otomatis per wilayah.'),
        ],
      ),
    );
  }

  Widget _buildWalletDetailCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                Text(desc, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.grey)),
              Text(address, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchTxnAndProduct(int transactionId) async {
    try {
      final db = await DBHelper.instance.database;
      final txns = await db.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (txns.isNotEmpty) {
        final txn = txns.first;
        final product = await Provider.of<ProductProvider>(context, listen: false).getProductById(txn['productId'] as int);
        return {'txn': txn, 'product': product};
      }
    } catch (e) {
      debugPrint('Error loading txn details for courier: $e');
    }
    return null;
  }
}
