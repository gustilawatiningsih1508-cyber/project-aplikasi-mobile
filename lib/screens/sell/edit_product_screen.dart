import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';

class EditProductScreen extends StatefulWidget {
  final ProductModel product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;

  late String _selectedCategory;
  late String _selectedCondition;
  final List<String> _imagePaths = [];
  static const int _maxImages = 5;

  final List<String> _categories = ['Elektronik', 'Pakaian', 'Mebel', 'Buku', 'Lainnya'];
  final List<String> _conditions = ['Baru', 'Sangat Baik', 'Baik', 'Cukup'];

  final List<Map<String, String>> _mockImages = [
    {'name': 'Elektronik/HP', 'asset': 'assets/images/placeholder.png'},
    {'name': 'Laptop/Kamera', 'asset': 'assets/images/placeholder.png'},
    {'name': 'Fashion/Baju', 'asset': 'assets/images/placeholder.png'},
    {'name': 'Kursi/Meja', 'asset': 'assets/images/placeholder.png'},
    {'name': 'Buku/Novel', 'asset': 'assets/images/placeholder.png'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
    _descriptionController = TextEditingController(text: widget.product.description);
    _selectedCategory = widget.product.category;
    _selectedCondition = widget.product.condition;
    
    if (widget.product.imageUrls != null) {
      _imagePaths.addAll(widget.product.imageUrls!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(ImageSource source) async {
    if (_imagePaths.length >= _maxImages) {
      _showMaxImageSnack();
      return;
    }
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final dataUri = 'data:image/jpeg;base64,$base64String';
        setState(() => _imagePaths.add(dataUri));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka kamera/galeri. Gunakan gambar demo.', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Demo', onPressed: _showMockImageSelector),
          ),
        );
      }
    }
  }

  void _showMaxImageSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maksimal $_maxImages foto per produk.', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMockImageSelector() {
    if (_imagePaths.length >= _maxImages) {
      _showMaxImageSnack();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Pilih Foto Demo', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _mockImages.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
            itemBuilder: (context, index) {
              final item = _mockImages[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(imageUrl: item['asset'], width: 50, height: 50),
                ),
                title: Text(item['name']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                onTap: () {
                  setState(() => _imagePaths.add(item['asset']!));
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey))
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) => setState(() => _imagePaths.removeAt(index));

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Harap tambahkan minimal 1 foto produk.', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedProduct = widget.product.copyWith(
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      condition: _selectedCondition,
      imageUrls: _imagePaths,
    );

    final success = await Provider.of<ProductProvider>(context, listen: false).updateProduct(updatedProduct);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil diperbarui!', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui produk.', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Edit Produk'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.deepBlueGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perbarui Detail Produk',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pastikan informasi produk selalu akurat.',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Foto Produk',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _imagePaths.length >= _maxImages ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_imagePaths.length}/$_maxImages foto',
                        style: GoogleFonts.poppins(
                          color: _imagePaths.length >= _maxImages ? AppTheme.errorColor : AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _imagePaths.length + (_imagePaths.length < _maxImages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _imagePaths.length) {
                      return GestureDetector(
                        onTap: _showImageSourceSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryColor, size: 32),
                              const SizedBox(height: 4),
                              Text(
                                'Tambah',
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AppImage(imageUrl: _imagePaths[index], fit: BoxFit.cover),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Text('Utama', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),
                
                Text('Informasi Produk', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Wajib diisi';
                    if (value.length < 5) return 'Minimal 5 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kategori', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          _buildDropdown(_categories, _selectedCategory, (val) => setState(() => _selectedCategory = val)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kondisi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          _buildDropdown(_conditions, _selectedCondition, (val) => setState(() => _selectedCondition = val)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                  decoration: InputDecoration(
                    labelText: 'Harga Jual',
                    prefixText: 'Rp ',
                    prefixStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Harga wajib diisi';
                    if (double.tryParse(value) == null) return 'Angka tidak valid';
                    if (double.parse(value) <= 0) return 'Harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    labelText: 'Deskripsi Detail',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Deskripsi wajib diisi';
                    if (value.length < 10) return 'Minimal 10 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                Consumer<ProductProvider>(
                  builder: (context, prov, _) => ElevatedButton(
                    onPressed: prov.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: prov.isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Simpan Perubahan'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(Icons.camera_alt_rounded, 'Kamera', AppTheme.primaryColor, () {
                    Navigator.pop(context);
                    _pickImages(ImageSource.camera);
                  }),
                  _buildSourceOption(Icons.photo_library_rounded, 'Galeri', AppTheme.accentColor, () {
                    Navigator.pop(context);
                    _pickImages(ImageSource.gallery);
                  }),
                  _buildSourceOption(Icons.image_search_rounded, 'Demo', AppTheme.warningColor, () {
                    Navigator.pop(context);
                    _showMockImageSelector();
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String selectedValue, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.primaryColor),
          onChanged: (String? val) {
            if (val != null) onChanged(val);
          },
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
