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

class MyPurchasesScreen extends StatefulWidget {
  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  List<TransactionModel> _purchases = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  // Rating state
  double _sellerRating = 5;
  double _courierRating = 5;
  final _sellerReviewController = TextEditingController();
  final _courierReviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  @override
  void dispose() {
    _sellerReviewController.dispose();
    _courierReviewController.dispose();
    super.dispose();
  }

  void _loadPurchases() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final history = await courierProv.getPurchaseHistory(auth.currentUser!.id!);

    if (mounted) {
      setState(() {
        _purchases = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadPaymentProof(int transactionId) async {
    // Simulasi upload bukti pembayaran
    setState(() => _isActionLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final proofUrl = 'bukti_transfer_${transactionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final success = await courierProv.uploadPaymentProof(transactionId, proofUrl);
    
    if (mounted) {
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Bukti pembayaran berhasil dikirim! Menunggu konfirmasi penjual.'
              : 'Gagal mengirim bukti pembayaran.'),
          backgroundColor: success ? AppTheme.primaryColor : Colors.red,
        ),
      );
      if (success) _loadPurchases();
    }
  }

  Future<void> _confirmReceived(int transactionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Terima Barang?'),
        content: const Text(
          'Pastikan barang sudah Anda terima dalam kondisi sesuai deskripsi. Setelah konfirmasi, transaksi akan dinyatakan selesai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Sudah Diterima'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final success = await courierProv.confirmItemReceived(transactionId);

    if (mounted) {
      setState(() => _isActionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barang dikonfirmasi diterima! Transaksi selesai.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        _loadPurchases();
      }
    }
  }

  void _showRatingDialog(TransactionModel txn) {
    _sellerRating = 5;
    _courierRating = 5;
    _sellerReviewController.clear();
    _courierReviewController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Text('Beri Ulasan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rating Penjual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => _sellerRating = (i + 1).toDouble()),
                      child: Icon(
                        i < _sellerRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _sellerReviewController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tulis ulasan untuk penjual...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Divider(height: 24),
                const Text('Rating Kurir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => _courierRating = (i + 1).toDouble()),
                      child: Icon(
                        i < _courierRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _courierReviewController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tulis ulasan untuk kurir...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () async {
                final courierProv = Provider.of<CourierProvider>(context, listen: false);
                final success = await courierProv.addRatings(
                  transactionId: txn.id!,
                  sellerRating: _sellerRating,
                  sellerReview: _sellerReviewController.text.trim(),
                  courierRating: _courierRating,
                  courierReview: _courierReviewController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Terima kasih atas ulasan Anda!'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                    _loadPurchases();
                  }
                }
              },
              child: const Text('Kirim Ulasan'),
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Pembelian Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchases,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _purchases.length,
                  itemBuilder: (context, index) {
                    final txn = _purchases[index];
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                      ),
                                      StatusBadge(status: txn.status),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // Product Info
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
                                              'Total Bayar: ${currencyFormatter.format(txn.amount)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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

                                  // Payment Proof Status (for bank transfer)
                                  if (!txn.paymentMethod.contains('COD') && txn.paymentProofUrl != null) ...[
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
                                          Text('Bukti transfer telah dikirim', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Rated badge
                                  if (txn.status == 'Selesai' && txn.sellerRating != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Ulasan dikirim: ${txn.sellerRating!.toStringAsFixed(1)} ⭐',
                                          style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // Action Buttons based on Status
                                  _buildActionButtons(txn),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildActionButtons(TransactionModel txn) {
    final buttons = <Widget>[];

    // Lacak Kiriman (for all active statuses with courier)
    if (txn.courierRequestId != null && !['Selesai', 'Dibatalkan'].contains(txn.status)) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourierTrackingScreen(transactionId: txn.id!),
              ),
            ).then((_) => _loadPurchases());
          },
          icon: const Icon(Icons.local_shipping, size: 15),
          label: const Text('Lacak Kiriman', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            side: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      );
    }

    // Upload Bukti Transfer
    if (txn.status == 'Menunggu Pembayaran' && !txn.paymentMethod.contains('COD') && txn.paymentProofUrl == null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _uploadPaymentProof(txn.id!),
          icon: _isActionLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload, size: 15),
          label: const Text('Upload Bukti Transfer', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    // Konfirmasi Terima Barang
    if (txn.status == 'Terkirim') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _isActionLoading ? null : () => _confirmReceived(txn.id!),
          icon: const Icon(Icons.check_circle_outline, size: 15),
          label: const Text('Konfirmasi Diterima', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    // Beri Rating
    if (txn.status == 'Selesai' && txn.sellerRating == null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _showRatingDialog(txn),
          icon: const Icon(Icons.star_outline, size: 15),
          label: const Text('Beri Ulasan', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
          ),
        ),
      );
    }

    // Lihat Detail (for completed)
    if (txn.status == 'Selesai' && txn.courierRequestId != null) {
      buttons.add(
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CourierTrackingScreen(transactionId: txn.id!)),
            );
          },
          icon: const Icon(Icons.info_outline, size: 14),
          label: const Text('Lihat Detail', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: buttons,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Belum ada pembelian',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Barang yang Anda beli akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
