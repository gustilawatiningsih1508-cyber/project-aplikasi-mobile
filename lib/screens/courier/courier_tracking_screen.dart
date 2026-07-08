import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/courier_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import '../../services/db_helper.dart';
import '../main_tab_container.dart';

class CourierTrackingScreen extends StatefulWidget {
  final int transactionId;

  const CourierTrackingScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<CourierTrackingScreen> createState() => _CourierTrackingScreenState();
}

class _CourierTrackingScreenState extends State<CourierTrackingScreen> {
  CourierModel? _courierRequest;
  ProductModel? _product;
  Map<String, dynamic>? _transaction;
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
    _loadCourierDetails();
  }

  @override
  void dispose() {
    _sellerReviewController.dispose();
    _courierReviewController.dispose();
    super.dispose();
  }

  void _loadCourierDetails() async {
    setState(() => _isLoading = true);

    try {
      // Langsung query dari DB berdasarkan transactionId (tidak bergantung pada list provider)
      final courierReq = await Provider.of<CourierProvider>(context, listen: false)
          .getCourierRequestByTransactionId(widget.transactionId);

      final db = await DBHelper.instance.database;
      final txns = await db.query('transactions', where: 'id = ?', whereArgs: [widget.transactionId]);

      if (txns.isNotEmpty) {
        final txn = txns.first;
        final prodId = txn['productId'] as int;
        final prod = await Provider.of<ProductProvider>(context, listen: false).getProductById(prodId);

        if (mounted) {
          setState(() {
            _courierRequest = courierReq;
            _transaction = txn;
            _product = prod;
          });
        }
      }
    } catch (e) {
      debugPrint('Error finding courier request: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerManualAdvance() async {
    if (_courierRequest == null) return;
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    await courierProv.advanceCourierStatus(_courierRequest!.id!);

    // Reload local state
    final updated = await courierProv.getCourierRequestById(_courierRequest!.id!);
    if (updated != null && mounted) {
      setState(() {
        _courierRequest = updated;
      });
    }
  }

  Future<void> _confirmReceived() async {
    setState(() => _isActionLoading = true);
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    final success = await courierProv.confirmItemReceived(widget.transactionId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barang berhasil dikonfirmasi diterima!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      _loadCourierDetails();
    }
    if (mounted) setState(() => _isActionLoading = false);
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              const Text('Beri Ulasan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  transactionId: widget.transactionId,
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
                    _loadCourierDetails();
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
    final auth = Provider.of<AuthProvider>(context);
    final isBuyer = auth.currentUser?.id == (_transaction?['buyerId'] as int?);
    final txnStatus = _transaction?['status'] as String? ?? '';
    final hasRated = (_transaction?['sellerRating'] != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Pengiriman'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainTabContainer(initialTab: 0)),
              (route) => false,
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courierRequest == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Data pengiriman tidak ditemukan.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCourierDetails,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Badge Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('No. Resi Pengiriman', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                Text(
                                  'BKG-REG-${1000 + _courierRequest!.id!}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                            StatusBadge(status: _courierRequest!.status),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Courier Info
                      if (_courierRequest!.courierId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Kurir Mitra', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    Text(
                                      _courierRequest!.courierName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_courierRequest!.price),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Product Card
                      if (_product != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade100,
                                  child: _product!.imageUrl.startsWith('http')
                                      ? Image.network(_product!.imageUrl, fit: BoxFit.cover)
                                      : const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _product!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(
                                        (_transaction?['amount'] as num? ?? 0.0).toDouble(),
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    ),
                                    Text(
                                      'Metode: ${_transaction?['paymentMethod'] ?? 'COD'}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Simulation Info alert (only show for active statuses)
                      if (!['Selesai', 'Dibatalkan'].contains(txnStatus))
                        _buildSimulationAlert(),
                      if (!['Selesai', 'Dibatalkan'].contains(txnStatus))
                        const SizedBox(height: 20),

                      // Buyer Action: Konfirmasi Terima Barang
                      if (isBuyer && txnStatus == 'Terkirim') ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '📦 Barang sudah tiba!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pastikan barang sesuai deskripsi dan kondisi baik sebelum konfirmasi.',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _isActionLoading ? null : _confirmReceived,
                                icon: _isActionLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('Konfirmasi Barang Diterima'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Buyer Action: Beri Rating (setelah Selesai, belum rating)
                      if (isBuyer && txnStatus == 'Selesai' && !hasRated) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                '⭐ Transaksi Selesai!',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Bagaimana pengalaman belanja Anda? Beri ulasan untuk penjual dan kurir.',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _showRatingDialog,
                                icon: const Icon(Icons.star_outline),
                                label: const Text('Beri Ulasan Sekarang'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Rating submitted
                      if (isBuyer && txnStatus == 'Selesai' && hasRated) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ulasan Terkirim ✓', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    Row(
                                      children: [
                                        ...List.generate((_transaction!['sellerRating'] as num? ?? 0).round(), (i) =>
                                            const Icon(Icons.star, color: Colors.amber, size: 14)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _transaction!['sellerReview']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tracking Timeline
                      const Text(
                        'Lacak Kiriman',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      _buildTrackingTimeline(txnStatus),
                      const Divider(height: 40),

                      // Address Section
                      _buildAddressSection(),
                      const SizedBox(height: 24),

                      // Tombol Percepat (hanya untuk status aktif, non-Selesai)
                      if (!['Selesai', 'Dibatalkan', 'Terkirim'].contains(txnStatus) &&
                          ['Barang Diambil', 'Dalam Perjalanan', 'Mencari Kurir'].contains(txnStatus))
                        CustomButton(
                          text: 'Simulasi Langkah Kurir (Percepat)',
                          icon: Icons.fast_forward,
                          isOutlined: true,
                          onPressed: _triggerManualAdvance,
                        ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Kembali Ke Beranda',
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const MainTabContainer(initialTab: 0)),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSimulationAlert() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: Colors.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Simulasi Demo: Gunakan tombol "Percepat" di bawah untuk maju ke status berikutnya, atau tunggu kurir update status dari dashboard kurir mereka.',
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(String currentStatus) {
    // Urutan semua status yang mungkin
    final allSteps = [
      {
        'status': 'Menunggu Konfirmasi Penjual',
        'title': 'Pesanan Dibuat',
        'desc': 'Pesanan Anda dikirim ke penjual untuk dikonfirmasi',
      },
      {
        'status': 'Menunggu Pembayaran',
        'title': 'Menunggu Pembayaran',
        'desc': 'Silakan lakukan transfer sesuai metode pembayaran',
      },
      {
        'status': 'Mencari Kurir',
        'title': 'Mencari Kurir',
        'desc': 'Sistem sedang mencari kurir yang tersedia di Bengkalis',
      },
      {
        'status': 'Barang Diambil',
        'title': 'Barang Dijemput Kurir',
        'desc': 'Kurir telah mengambil barang dari lokasi penjual',
      },
      {
        'status': 'Dalam Perjalanan',
        'title': 'Dalam Pengiriman',
        'desc': 'Barang sedang dibawa menuju alamat tujuan Anda',
      },
      {
        'status': 'Terkirim',
        'title': 'Tiba di Tujuan',
        'desc': 'Barang telah tiba, silakan konfirmasi penerimaan',
      },
      {
        'status': 'Selesai',
        'title': 'Transaksi Selesai',
        'desc': 'Transaksi berhasil diselesaikan',
      },
    ];

    // Jika dibatalkan, tampilkan status batal saja
    if (currentStatus == 'Dibatalkan') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Transaksi ini dibatalkan.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // Cari posisi status saat ini
    final currentIndex = allSteps.indexWhere((s) => s['status'] == currentStatus);
    final activeIndex = currentIndex == -1 ? 0 : currentIndex;

    // Filter step berdasarkan metode pembayaran (COD skip Menunggu Pembayaran)
    final isCOD = _transaction?['paymentMethod']?.toString().contains('COD') ?? true;
    final visibleSteps = allSteps.where((s) {
      if (isCOD && s['status'] == 'Menunggu Pembayaran') return false;
      return true;
    }).toList();

    final visibleActiveIndex = visibleSteps.indexWhere((s) => s['status'] == currentStatus);
    final visibleActive = visibleActiveIndex == -1 ? 0 : visibleActiveIndex;

    return Column(
      children: List.generate(visibleSteps.length, (index) {
        final step = visibleSteps[index];
        final isCompleted = index <= visibleActive;
        final isLast = index == visibleSteps.length - 1;
        final isCurrent = index == visibleActive;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.primaryColor : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 6, spreadRadius: 1)]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: index < visibleActive ? AppTheme.primaryColor : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title']!,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.bold,
                      fontSize: isCurrent ? 14 : 13,
                      color: isCompleted ? AppTheme.textPrimary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['desc']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? AppTheme.textSecondary : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alamat Penjual (Pickup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      _courierRequest!.pickupAddress,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(indent: 32),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alamat Pengantaran (Tujuan)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      _courierRequest!.deliveryAddress,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
