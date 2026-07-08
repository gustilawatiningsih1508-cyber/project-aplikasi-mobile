import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../sell/edit_product_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<ProductModel> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  void _loadListings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);

    final productProv = Provider.of<ProductProvider>(context, listen: false);
    final list = await productProv.getUserListings(auth.currentUser!.id!);

    if (mounted) {
      setState(() {
        _listings = list;
        _isLoading = false;
      });
    }
  }

  void _toggleProductStatus(ProductModel product) async {
    // Only allow toggling if status is Tersedia or Terjual (not Pending)
    if (product.status == 'Pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk sedang dalam proses transaksi, status tidak dapat diubah.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final nextStatus = product.status == 'Tersedia' ? 'Terjual' : 'Tersedia';
    final productProv = Provider.of<ProductProvider>(context, listen: false);
    await productProv.updateProductStatus(product.id!, nextStatus);
    _loadListings();
  }

  void _editProduct(ProductModel product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: product),
      ),
    );
    if (result == true) {
      _loadListings();
    }
  }

  void _deleteProduct(ProductModel product) async {
    if (product.status == 'Pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk sedang dalam proses transaksi dan tidak dapat dihapus.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Apakah Anda yakin ingin menghapus "${product.name}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final productProv = Provider.of<ProductProvider>(context, listen: false);
    final success = await productProv.deleteProduct(product.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Produk berhasil dihapus.' : 'Gagal menghapus produk.'),
          backgroundColor: success ? Colors.red : Colors.grey,
        ),
      );
      if (success) _loadListings();
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
        title: const Text('Iklan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadListings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final item = _listings[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 1,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Product Image
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey.shade100,
                                  child: item.imageUrl.startsWith('http')
                                      ? Image.network(item.imageUrl, fit: BoxFit.cover)
                                      : const Icon(Icons.image, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                // Details
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currencyFormatter.format(item.price),
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            StatusBadge(status: item.status),
                                            const Spacer(),
                                            // Toggle status button (only for Available/Sold)
                                            if (item.status != 'Pending')
                                              InkWell(
                                                onTap: () => _toggleProductStatus(item),
                                                child: Tooltip(
                                                  message: item.status == 'Tersedia'
                                                      ? 'Tandai Terjual'
                                                      : 'Tandai Tersedia',
                                                  child: Icon(
                                                    item.status == 'Tersedia'
                                                        ? Icons.check_circle_outline
                                                        : Icons.storefront,
                                                    size: 20,
                                                    color: AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Action buttons row
                            Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: item.status == 'Pending'
                                          ? null
                                          : () => _editProduct(item),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  Container(width: 1, height: 30, color: Colors.grey.shade200),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: item.status == 'Pending'
                                          ? null
                                          : () => _deleteProduct(item),
                                      icon: const Icon(Icons.delete_outline, size: 16),
                                      label: const Text('Hapus', style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Belum ada produk terdaftar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Klik tombol Jual untuk mengiklankan barang bekas pertama Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
