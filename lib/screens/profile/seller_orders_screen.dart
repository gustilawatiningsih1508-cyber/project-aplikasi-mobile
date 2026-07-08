import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../courier/courier_tracking_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TransactionModel> _pendingOrders = [];
  List<TransactionModel> _activeOrders = [];
  List<TransactionModel> _completedOrders = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);

    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final allSales = await courierProv.getSellerTransactions(auth.currentUser!.id!);

    if (mounted) {
      setState(() {
        _pendingOrders = allSales
            .where((t) => t.status == 'Menunggu Konfirmasi Penjual')
            .toList();
        _activeOrders = allSales
            .where((t) => [
                  'Menunggu Pembayaran',
                  'Mencari Kurir',
                  'Barang Diambil',
                  'Dalam Perjalanan',
                  'Terkirim',
                ].contains(t.status))
            .toList();
        _completedOrders = allSales
            .where((t) => ['Selesai', 'Dibatalkan'].contains(t.status))
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmOrder(TransactionModel txn) async {
    setState(() => _isActionLoading = true);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final success = await courierProv.confirmOrder(txn.id!, txn.paymentMethod);

    if (mounted) {
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? txn.paymentMethod.contains('COD')
                  ? 'Pesanan dikonfirmasi! Sistem sedang mencari kurir.'
                  : 'Pesanan dikonfirmasi! Menunggu pembayaran dari pembeli.'
              : 'Gagal mengkonfirmasi pesanan.'),
          backgroundColor: success ? AppTheme.primaryColor : Colors.red,
        ),
      );
      if (success) _loadOrders();
    }
  }

  Future<void> _rejectOrder(TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pesanan?'),
        content: const Text(
          'Apakah Anda yakin ingin menolak pesanan ini? Produk akan kembali tersedia untuk pembeli lain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak Pesanan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final success = await courierProv.rejectOrder(txn.id!);

    if (mounted) {
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Pesanan berhasil ditolak.' : 'Gagal menolak pesanan.'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
      if (success) _loadOrders();
    }
  }

  Future<void> _confirmPayment(TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran?'),
        content: const Text(
          'Pastikan Anda telah menerima pembayaran dari pembeli sebelum melanjutkan. Pesanan akan segera dicarikan kurir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Pembayaran Diterima'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final success = await courierProv.confirmPayment(txn.id!);

    if (mounted) {
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Pembayaran dikonfirmasi! Sistem mencari kurir.'
              : 'Gagal konfirmasi pembayaran.'),
          backgroundColor: success ? AppTheme.primaryColor : Colors.red,
        ),
      );
      if (success) _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Masuk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Perlu Aksi'),
                  if (_pendingOrders.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingOrders.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Aktif'),
            const Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_pendingOrders, currencyFormatter, isPending: true),
                _buildOrderList(_activeOrders, currencyFormatter, isActive: true),
                _buildOrderList(_completedOrders, currencyFormatter),
              ],
            ),
    );
  }

  Widget _buildOrderList(
    List<TransactionModel> orders,
    NumberFormat fmt, {
    bool isPending = false,
    bool isActive = false,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.assignment_late_outlined : Icons.receipt_long_outlined,
              size: 70,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'Tidak ada pesanan yang perlu dikonfirmasi'
                  : isActive
                      ? 'Tidak ada pesanan aktif'
                      : 'Belum ada riwayat pesanan',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final txn = orders[index];
        return FutureBuilder<ProductModel?>(
          future: Provider.of<ProductProvider>(context, listen: false).getProductById(txn.productId),
          builder: (context, snapshot) {
            final product = snapshot.data;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'INV-TXN-${1000 + txn.id!}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          StatusBadge(status: txn.status),
                        ],
                      ),
                      const Divider(height: 16),

                      // Product info
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade100,
                              child: product?.imageUrl.startsWith('http') == true
                                  ? Image.network(product!.imageUrl, fit: BoxFit.cover)
                                  : const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product?.name ?? 'Memuat...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Total: ${fmt.format(txn.amount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                Text(
                                  'Metode: ${txn.paymentMethod}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Payment proof badge
                      if (txn.status == 'Menunggu Pembayaran' && txn.paymentProofUrl != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.receipt_long, size: 14, color: Colors.blue),
                              SizedBox(width: 6),
                              Text(
                                'Bukti transfer sudah dikirim pembeli',
                                style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Action buttons
                      _buildSellerActionButtons(txn),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSellerActionButtons(TransactionModel txn) {
    final buttons = <Widget>[];

    // Konfirmasi dan Tolak untuk pesanan baru
    if (txn.status == 'Menunggu Konfirmasi Penjual') {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _isActionLoading ? null : () => _rejectOrder(txn),
          icon: const Icon(Icons.close, size: 15, color: Colors.red),
          label: const Text('Tolak', style: TextStyle(color: Colors.red, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _confirmOrder(txn),
          icon: _isActionLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 15),
          label: const Text('Konfirmasi Pesanan', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    // Konfirmasi pembayaran untuk transfer manual
    if (txn.status == 'Menunggu Pembayaran' && txn.paymentProofUrl != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _confirmPayment(txn),
          icon: const Icon(Icons.payment, size: 15),
          label: const Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    // Lacak pengiriman
    if (txn.courierRequestId != null && !['Selesai', 'Dibatalkan', 'Menunggu Konfirmasi Penjual', 'Menunggu Pembayaran'].contains(txn.status)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourierTrackingScreen(transactionId: txn.id!),
              ),
            ).then((_) => _loadOrders());
          },
          icon: const Icon(Icons.local_shipping, size: 15),
          label: const Text('Lacak Pengiriman', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            side: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: buttons,
      ),
    );
  }
}
