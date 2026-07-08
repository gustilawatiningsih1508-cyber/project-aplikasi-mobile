import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../services/db_helper.dart';
import '../chat/chat_room_screen.dart';
import '../courier/courier_request_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductModel? _product;
  Map<String, dynamic>? _sellerInfo;
  bool _isLoading = true;
  int _currentImageIndex = 0;
  final PageController _imgController = PageController();

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _imgController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final p = await provider.getProductById(widget.productId);
    if (p != null && mounted) {
      setState(() => _product = p);
      try {
        final db = await DBHelper.instance.database;
        final res = await db.query('users', where: 'id = ?', whereArgs: [p.sellerId]);
        if (mounted && res.isNotEmpty) {
          setState(() => _sellerInfo = res.first);
        }
      } catch (e) {
        debugPrint('Error loading seller: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Color _conditionColor(String c) {
    switch (c) {
      case 'Baru': return AppTheme.primaryColor;
      case 'Sangat Baik': return AppTheme.successColor;
      case 'Baik': return AppTheme.warningColor;
      default: return Colors.grey;
    }
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
    } catch (_) { return ''; }
  }

  void _showAuthWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anda harus masuk terlebih dahulu.', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showBidDialog(BuildContext context, ProductModel p, int sellerId) {
    final bidController = TextEditingController(text: p.price.toInt().toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tawar Harga', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga asli: Rp ${NumberFormat('#,###', 'id_ID').format(p.price)}',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: bidController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              decoration: InputDecoration(
                labelText: 'Harga Tawar (Rp)',
                labelStyle: GoogleFonts.poppins(fontSize: 13),
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final bidPrice = double.tryParse(bidController.text);
              if (bidPrice == null || bidPrice <= 0) return;
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    contactId: sellerId,
                    contactName: p.sellerName,
                    initialBidProduct: p,
                    initialBidPrice: bidPrice,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Kirim Tawaran', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }
    if (_product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: Center(
          child: Text('Produk tidak ditemukan.', style: GoogleFonts.poppins()),
        ),
      );
    }

    final p = _product!;
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final isMyProduct = currentUser != null && currentUser.id == p.sellerId;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final images = p.imageUrls.isNotEmpty ? p.imageUrls : ['assets/images/placeholder.png'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ===== IMAGE APP BAR =====
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Image PageView
                  PageView.builder(
                    controller: _imgController,
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemBuilder: (_, i) => Hero(
                      tag: 'product-${p.id}',
                      child: AppImage(imageUrl: images[i], fit: BoxFit.cover),
                    ),
                  ),
                  // Image indicators
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == i ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == i ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        )),
                      ),
                    ),
                  // Condition badge
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 52,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _conditionColor(p.condition).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Text(
                        p.condition,
                        style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== CONTENT =====
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatter.format(p.price),
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tags row
                    Row(
                      children: [
                        _tag(Icons.category_outlined, p.category, Colors.blue.shade50, AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        _tag(Icons.calendar_today_outlined, _formatDate(p.createdAt),
                            Colors.grey.shade100, AppTheme.textSecondary),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.status == 'Tersedia'
                                ? AppTheme.successColor.withOpacity(0.1)
                                : AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.status,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.status == 'Tersedia' ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade100),
                    const SizedBox(height: 20),

                    // Description
                    Text('Deskripsi Produk',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(
                      p.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.7,
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(color: Colors.grey.shade100),
                    const SizedBox(height: 20),

                    // Seller Info
                    Text('Profil Penjual',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    _buildSellerCard(p),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ===== BOTTOM ACTION BAR =====
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: isMyProduct
              ? Center(
                  child: Text(
                    '✓ Ini adalah produk Anda',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Chat Button
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor),
                        onPressed: () {
                          if (currentUser == null) { _showAuthWarning(); return; }
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              contactId: p.sellerId,
                              contactName: p.sellerName,
                            ),
                          ));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Tawar Harga Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            if (currentUser == null) { _showAuthWarning(); return; }
                            if (p.status != 'Tersedia') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Barang tidak tersedia untuk ditawar')));
                              return;
                            }
                            _showBidDialog(context, p, p.sellerId);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Tawar',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Buy Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (currentUser == null) { _showAuthWarning(); return; }
                            if (p.status != 'Tersedia') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Barang sudah tidak tersedia')));
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CourierRequestScreen(product: p),
                            ));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Beli Sekarang',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(ProductModel p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.lightBlue),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              child: AppImage(
                imageUrl: _sellerInfo?['photoUrl'],
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(24),
                placeholder: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.sellerName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.verified, size: 13, color: AppTheme.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'Penjual Terverifikasi',
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (_sellerInfo?['address'] != null && _sellerInfo!['address'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _sellerInfo!['address'].toString().split(',').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
