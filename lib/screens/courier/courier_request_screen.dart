import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/db_helper.dart';
import 'courier_tracking_screen.dart';


class CourierRequestScreen extends StatefulWidget {
  final ProductModel product;
  final double? customPrice;

  const CourierRequestScreen({
    super.key,
    required this.product,
    this.customPrice,
  });

  @override
  State<CourierRequestScreen> createState() => _CourierRequestScreenState();
}

class _CourierRequestScreenState extends State<CourierRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressDetailController = TextEditingController();
  
  String _selectedVillage = 'Bengkalis Kota';
  String _selectedPaymentMethod = 'Cash on Delivery (COD)';
  double _shippingFee = 12000.0;
  
  List<Map<String, dynamic>> _userAddresses = [];
  Map<String, dynamic>? _selectedAddressMap;
  Map<String, dynamic>? _sellerInfo;

  final List<String> _paymentMethods = [
    'Cash on Delivery (COD)',
    'Transfer Bank (BRI/Mandiri)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSellerAndAddresses();
  }

  void _fetchSellerAndAddresses() async {
    // 1. Fetch seller details
    try {
      final db = await DBHelper.instance.database;
      final res = await db.query('users', where: 'id = ?', whereArgs: [widget.product.sellerId]);
      if (res.isNotEmpty && mounted) {
        setState(() {
          _sellerInfo = res.first;
        });
      }
    } catch (_) {}

    // 2. Fetch buyer addresses
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      try {
        final list = await DBHelper.instance.getUserAddresses(auth.currentUser!.id!);
        if (list.isNotEmpty && mounted) {
          final primary = list.firstWhere((a) => a['isPrimary'] == 1, orElse: () => list.first);
          setState(() {
            _userAddresses = list;
            _selectedAddressMap = primary;
            _selectedVillage = primary['village'];
            _addressDetailController.text = primary['detail'];
          });
          _recalculateShipping();
        }
      } catch (e) {
        debugPrint('Error loading buyer addresses: $e');
      }
    }
  }

  String extractVillage(String address) {
    if (address.contains(', Desa/Kel. ')) {
      final parts = address.split(', Desa/Kel. ');
      if (parts.length > 1 && parts[1].contains(', Kec. ')) {
        return parts[1].split(', Kec. ')[0].trim();
      }
      return parts[1].trim();
    }
    return 'Bengkalis Kota'; // fallback
  }

  void _recalculateShipping() {
    if (_sellerInfo == null) return;
    
    final sellerAddr = _sellerInfo!['address'] as String? ?? '';
    final sellerVillage = extractVillage(sellerAddr);
    
    final courierProv = Provider.of<CourierProvider>(context, listen: false);
    setState(() {
      _shippingFee = courierProv.calculateShippingFee(sellerVillage, _selectedVillage);
    });
  }

  void _changeAddressBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pilih Alamat Pengiriman',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _userAddresses.isEmpty
                        ? const Center(child: Text('Belum ada alamat tersimpan.'))
                        : ListView.builder(
                            itemCount: _userAddresses.length,
                            itemBuilder: (context, index) {
                              final addr = _userAddresses[index];
                              final isSelected = _selectedAddressMap?['id'] == addr['id'];

                              return ListTile(
                                leading: Icon(Icons.home, color: isSelected ? AppTheme.primaryColor : Colors.grey),
                                title: Text(addr['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${addr['village']} - ${addr['detail']}'),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedAddressMap = addr;
                                    _selectedVillage = addr['village'];
                                    _addressDetailController.text = addr['detail'];
                                    _recalculateShipping();
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
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

  @override
  void dispose() {
    _addressDetailController.dispose();
    super.dispose();
  }

  void _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final courierProvider = Provider.of<CourierProvider>(context, listen: false);

    if (!auth.isAuthenticated) return;

    final buyer = auth.currentUser!;
    final deliveryAddress = '${_addressDetailController.text.trim()}, Desa/Kel. $_selectedVillage, Kec. Bengkalis';

    // For demo, pickup address is seller's profile address
    // We can query SQLite for seller address or set a default
    String pickupAddress = 'Desa Senggoro, Bengkalis City';
    try {
      final db = await providerDBHelperQuery(widget.product.sellerId);
      if (db != null) {
        pickupAddress = db['address'] as String;
      }
    } catch (_) {}

    final actualPrice = widget.customPrice ?? widget.product.price;
    final txnId = await courierProvider.createPurchaseAndCourierRequest(
      productId: widget.product.id!,
      buyerId: buyer.id!,
      sellerId: widget.product.sellerId,
      amount: actualPrice,
      paymentMethod: _selectedPaymentMethod,
      pickupAddress: pickupAddress,
      deliveryAddress: deliveryAddress,
      shippingFee: _shippingFee,
    );

    if (txnId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembelian & penjemputan kurir berhasil dibuat!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );

      // Navigate directly to Courier Tracking Screen for this courierRequest
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CourierTrackingScreen(
            transactionId: txnId,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuat pesanan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> providerDBHelperQuery(int sellerId) async {
    final db = await providerGetDBInstance();
    final res = await db.query('users', where: 'id = ?', whereArgs: [sellerId]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<dynamic> providerGetDBInstance() async {
    // Return database instance
    final db = await DBHelper.instance.database;
    return db;
  }

  @override
  Widget build(BuildContext context) {
    final courierProv = Provider.of<CourierProvider>(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final productPrice = widget.customPrice ?? widget.product.price;
    final shippingFee = _shippingFee;
    final totalPrice = productPrice + shippingFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran & Pengiriman'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Summary
                _buildProductSummary(currencyFormatter),
                const SizedBox(height: 24),

                // Bengkalis City Courier Restricting notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kurir Lokal Bengkalis (Berbasis Zona)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                            ),
                            Text(
                              'Tarif berdasarkan zona kelurahan. Ongkir: ${currencyFormatter.format(shippingFee)}.',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Inputs for Destination
                const Text(
                  'Alamat Pengiriman (Dalam Bengkalis)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 12),
                
                // Village dropdown selection
                const Text('Desa/Kelurahan Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVillage,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() {
                            _selectedVillage = val;
                          });
                        }
                      },
                      items: courierProv.bengkalisCityVillages
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 15)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Detail Address field
                CustomTextField(
                  controller: _addressDetailController,
                  labelText: 'Detail Alamat Penerima',
                  hintText: 'Nama jalan, blok rumah, RT/RW',
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Detail alamat tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Payment Method selection
                const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() {
                            _selectedPaymentMethod = val;
                          });
                        }
                      },
                      items: _paymentMethods.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 15)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Price Summary Billing
                _buildBillingSummary(currencyFormatter, productPrice, shippingFee, totalPrice),
                const SizedBox(height: 32),

                // Show custom price if bidding was accepted
                if (widget.customPrice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gavel, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Harga tawaran Anda ${currencyFormatter.format(widget.customPrice!)} telah disetujui penjual.',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Checkout button
                CustomButton(
                  text: 'Konfirmasi & Pesan Sekarang',
                  isLoading: courierProv.isLoading,
                  onPressed: _submitOrder,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductSummary(NumberFormat fmt) {
    return Container(
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
            child: widget.product.imageUrl.startsWith('http')
                ? Image.network(widget.product.imageUrl, width: 70, height: 70, fit: BoxFit.cover)
                : const Icon(Icons.image, size: 70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Penjual: ${widget.product.sellerName}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(widget.product.price),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingSummary(NumberFormat fmt, double price, double fee, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Harga Barang', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text(fmt.format(price), style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Biaya Kurir Lokal', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text(fmt.format(fee), style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
              Text(
                fmt.format(total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
