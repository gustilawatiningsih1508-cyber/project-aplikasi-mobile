import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../courier/courier_tracking_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TransactionModel> _purchases = [];
  List<TransactionModel> _sales = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);

    final userId = auth.currentUser!.id!;
    final courierProv = Provider.of<CourierProvider>(context, listen: false);

    final buys = await courierProv.getPurchaseHistory(userId);
    final sells = await courierProv.getSellerTransactions(userId);

    if (mounted) {
      setState(() {
        _purchases = buys;
        _sales = sells;
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
          content: Text(success ? 'Pesanan dikonfirmasi!' : 'Gagal mengkonfirmasi pesanan.'),
          backgroundColor: success ? AppTheme.primaryColor : Colors.red,
        ),
      );
      if (success) _loadHistory();
    }
  }

  Future<void> _rejectOrder(TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pesanan?'),
        content: const Text('Produk akan kembali tersedia untuk pembeli lain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
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
          content: Text(success ? 'Pesanan ditolak.' : 'Gagal menolak pesanan.'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
      if (success) _loadHistory();
    }
  }

  Future<void> _confirmPayment(TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran?'),
        content: const Text('Pastikan pembayaran sudah diterima sebelum konfirmasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
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
          content: Text(success ? 'Pembayaran dikonfirmasi! Mencari kurir.' : 'Gagal konfirmasi.'),
          backgroundColor: success ? AppTheme.primaryColor : Colors.red,
        ),
      );
      if (success) _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pembelian (Beli)'),
            Tab(text: 'Penjualan (Jual)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(_purchases, isPurchase: true),
                _buildTransactionList(_sales, isPurchase: false),
              ],
            ),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> list, {required bool isPurchase}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isPurchase ? 'Belum ada pembelian' : 'Belum ada penjualan',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isPurchase
                  ? 'Transaksi belanja Anda akan tercatat di sini.'
                  : 'Barang Anda yang dibeli orang lain akan tercatat di sini.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final txn = list[index];
        return FutureBuilder<ProductModel?>(
          future: Provider.of<ProductProvider>(context, listen: false).getProductById(txn.productId),
          builder: (context, snapshot) {
            final product = snapshot.data;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INV-TXN-${1000 + txn.id!}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                              ),
                              Text(
                                _formatDate(txn.createdAt),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                            ],
                          ),
                          StatusBadge(status: txn.status),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
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
                                  isPurchase
                                      ? 'Penjual: ${product?.sellerName ?? "..."}'
                                      : 'Pembeli ID: ${txn.buyerId}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormatter.format(txn.amount),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Payment proof badge (buyer uploaded)
                      if (!isPurchase && txn.status == 'Menunggu Pembayaran' && txn.paymentProofUrl != null) ...[
                        const SizedBox(height: 8),
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

                      // Seller action buttons
                      if (!isPurchase) ...[
                        const SizedBox(height: 10),
                        _buildSellerActions(txn),
                      ],

                      // Courier tracking link for both
                      if (txn.courierRequestId != null && isPurchase) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CourierTrackingScreen(transactionId: txn.id!),
                                ),
                              ).then((_) => _loadHistory());
                            },
                            icon: const Icon(Icons.local_shipping, size: 16),
                            label: const Text('Rincian Kurir'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSellerActions(TransactionModel txn) {
    final buttons = <Widget>[];

    if (txn.status == 'Menunggu Konfirmasi Penjual') {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _isActionLoading ? null : () => _rejectOrder(txn),
          icon: const Icon(Icons.close, size: 14, color: Colors.red),
          label: const Text('Tolak', style: TextStyle(color: Colors.red, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
        ),
      );
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _confirmOrder(txn),
          icon: const Icon(Icons.check, size: 14),
          label: const Text('Konfirmasi', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    if (txn.status == 'Menunggu Pembayaran' && txn.paymentProofUrl != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _confirmPayment(txn),
          icon: const Icon(Icons.payment, size: 14),
          label: const Text('Konfirmasi Bayar', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    if (txn.courierRequestId != null &&
        !['Selesai', 'Dibatalkan', 'Menunggu Konfirmasi Penjual', 'Menunggu Pembayaran'].contains(txn.status)) {
      buttons.add(
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourierTrackingScreen(transactionId: txn.id!),
              ),
            ).then((_) => _loadHistory());
          },
          icon: const Icon(Icons.local_shipping, size: 14),
          label: const Text('Lacak', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: buttons,
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }
}
