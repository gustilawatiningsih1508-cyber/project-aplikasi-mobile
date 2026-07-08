import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/db_helper.dart';
import 'add_edit_address_screen.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  void _loadAddresses() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final list = await DBHelper.instance.getUserAddresses(auth.currentUser!.id!);
      setState(() {
        _addresses = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user addresses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deleteAddress(int id, bool isPrimary) async {
    if (isPrimary && _addresses.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubah alamat utama lain terlebih dahulu sebelum menghapus alamat ini.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    try {
      await DBHelper.instance.deleteAddress(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat berhasil dihapus.'),
          backgroundColor: Colors.red,
        ),
      );
      _loadAddresses();
    } catch (e) {
      debugPrint('Error deleting address: $e');
    }
  }

  void _setAsPrimary(int id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    try {
      await DBHelper.instance.setPrimaryAddress(auth.currentUser!.id!, id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat utama berhasil diperbarui!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      _loadAddresses();
    } catch (e) {
      debugPrint('Error setting primary address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Alamat Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
              ).then((shouldReload) {
                if (shouldReload == true) _loadAddresses();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    final isPrimary = addr['isPrimary'] == 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isPrimary ? AppTheme.primaryColor : Colors.grey.shade200,
                          width: isPrimary ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.home, color: AppTheme.primaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      addr['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                if (isPrimary)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'UTAMA',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Kelurahan: ${addr['village']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr['detail'],
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Action to set primary
                                if (!isPrimary)
                                  TextButton(
                                    onPressed: () => _setAsPrimary(addr['id']),
                                    child: const Text('Jadikan Utama', style: TextStyle(fontSize: 12)),
                                  )
                                else
                                  const SizedBox.shrink(),
                                
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddEditAddressScreen(address: addr),
                                          ),
                                        ).then((shouldReload) {
                                          if (shouldReload == true) _loadAddresses();
                                        });
                                      },
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Ubah', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Alamat?'),
                                            content: const Text('Apakah Anda yakin ingin menghapus alamat ini?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Batal'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteAddress(addr['id'], isPrimary);
                                                },
                                                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                                      label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
          ).then((shouldReload) {
            if (shouldReload == true) _loadAddresses();
          });
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Belum ada alamat tersimpan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan alamat Anda untuk memudahkan proses pengiriman kurir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
                ).then((shouldReload) {
                  if (shouldReload == true) _loadAddresses();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Alamat Pertama'),
            ),
          ],
        ),
      ),
    );
  }
}
