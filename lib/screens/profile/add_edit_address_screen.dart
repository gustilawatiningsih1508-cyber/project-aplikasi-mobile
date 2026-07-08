import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/db_helper.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // Null if adding new

  const AddEditAddressScreen({
    super.key,
    this.address,
  });

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressDetailController = TextEditingController();
  
  String _selectedVillage = 'Bengkalis Kota';
  bool _isPrimary = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _nameController.text = widget.address!['name'] ?? '';
      _addressDetailController.text = widget.address!['detail'] ?? '';
      _selectedVillage = widget.address!['village'] ?? 'Bengkalis Kota';
      _isPrimary = widget.address!['isPrimary'] == 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  void _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    
    final userId = auth.currentUser!.id!;
    final addressData = {
      'userId': userId,
      'name': _nameController.text.trim(),
      'village': _selectedVillage,
      'detail': _addressDetailController.text.trim(),
      'isPrimary': _isPrimary ? 1 : 0,
    };

    try {
      if (widget.address == null) {
        // Add new
        await DBHelper.instance.addAddress(addressData);
      } else {
        // Edit existing
        await DBHelper.instance.updateAddress(widget.address!['id'], addressData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat berhasil disimpan!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger reload
      }
    } catch (e) {
      debugPrint('Error saving address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan alamat.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final villages = Provider.of<CourierProvider>(context, listen: false).bengkalisCityVillages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? 'Tambah Alamat Baru' : 'Ubah Alamat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Label Alamat',
                  hintText: 'Contoh: Rumah, Kantor, Kos',
                  prefixIcon: Icons.bookmark_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Label tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Desa/Kelurahan di Kota Bengkalis',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF212121),
                  ),
                ),
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
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedVillage = newValue;
                          });
                        }
                      },
                      items: villages.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 15)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _addressDetailController,
                  labelText: 'Detail Alamat',
                  hintText: 'Nama jalan, blok, RT/RW, nomor rumah',
                  prefixIcon: Icons.home_outlined,
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Detail alamat tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Set as Primary switch
                SwitchListTile(
                  title: const Text(
                    'Jadikan Alamat Utama',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Gunakan alamat ini otomatis saat melakukan pembelian',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _isPrimary,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _isPrimary = value;
                    });
                  },
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Simpan Alamat',
                  isLoading: _isLoading,
                  onPressed: _saveAddress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
