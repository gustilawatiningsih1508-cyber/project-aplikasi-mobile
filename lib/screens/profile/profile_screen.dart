import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../notifications_screen.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'my_listings_screen.dart';
import 'my_purchases_screen.dart';
import 'seller_orders_screen.dart';
import 'address_list_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Silakan masuk untuk melihat profil',
                  style: GoogleFonts.poppins(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen())
                ),
                child: const Text('Masuk'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: AppImage(
                                  imageUrl: user.photoUrl,
                                  fit: BoxFit.cover,
                                  placeholder: const Icon(Icons.person, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Quick Stats / Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              Icons.shopping_bag_rounded, 'Transaksi', '0', AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              Icons.star_rounded, 'Rating', '0.0', AppTheme.warningColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Menu Options
                    _buildMenuSection(
                      title: 'Aktivitas Saya',
                      items: [
                        _MenuItem(
                          icon: Icons.list_alt_rounded,
                          title: 'Barang Jualan Saya',
                          color: AppTheme.primaryColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.shopping_cart_outlined,
                          title: 'Pembelian Saya',
                          color: AppTheme.accentColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPurchasesScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.storefront_rounded,
                          title: 'Pesanan Masuk (Penjual)',
                          color: AppTheme.warningColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SellerOrdersScreen())),
                        ),
                      ],
                    ),

                    _buildMenuSection(
                      title: 'Pengaturan Akun',
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Edit Profil',
                          color: AppTheme.successColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.location_on_outlined,
                          title: 'Daftar Alamat',
                          color: AppTheme.errorColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressListScreen())),
                        ),
                        _MenuItem(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifikasi',
                          color: Colors.purple,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.errorColor,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text('Keluar Akun', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.1),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({required String title, required List<_MenuItem> items}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: item.color.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      title: Text(
                        item.title,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: item.onTap,
                    ),
                    if (index < items.length - 1)
                      Divider(color: Colors.grey.shade100, height: 1, indent: 64, endIndent: 20),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({required this.icon, required this.title, required this.color, required this.onTap});
}
