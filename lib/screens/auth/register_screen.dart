import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courier_provider.dart';
import '../../theme/app_theme.dart';
import '../main_tab_container.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ktpController = TextEditingController();
  final _vehicleController = TextEditingController();
  
  String _selectedVillage = 'Bengkalis Kota'; // Default village
  String _selectedRole = 'user'; // 'user' or 'courier'
  bool _obscurePassword = true;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ktpController.dispose();
    _vehicleController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final fullAddress = '${_addressController.text.trim()}, Desa/Kel. $_selectedVillage, Kec. Bengkalis';
    
    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      address: fullAddress,
      role: _selectedRole,
      ktp: _selectedRole == 'courier' ? _ktpController.text.trim() : null,
      vehicle: _selectedRole == 'courier' ? _vehicleController.text.trim() : null,
    );

    if (success && mounted) {
      if (_selectedRole == 'courier') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Pendaftaran Berhasil', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
            content: Text(
              'Akun kurir Anda telah dibuat. Silakan hubungi admin atau tunggu approval sebelum dapat digunakan.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: Text('OK, Mengerti', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainTabContainer()),
          (route) => false,
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Pendaftaran gagal', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final villages = Provider.of<CourierProvider>(context, listen: false).bengkalisCityVillages;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bergabung dengan BeliBekas',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lengkapi data Anda untuk mulai bertransaksi.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Registration Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 16)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Daftar Sebagai', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildRoleCard('user', Icons.person_rounded, 'Pengguna'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildRoleCard('courier', Icons.delivery_dining_rounded, 'Kurir'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              
                              _buildTextField(
                                controller: _nameController,
                                label: 'Nama Lengkap',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Email tidak valid';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: _buildPrefixIcon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Wajib diisi';
                                  if (v.length < 6) return 'Minimal 6 karakter';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _phoneController,
                                label: 'No. WhatsApp',
                                icon: Icons.phone_android_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                              ),
                              
                              if (_selectedRole == 'courier') ...[
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _ktpController,
                                  label: 'Nomor KTP (16 Digit)',
                                  icon: Icons.badge_outlined,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (_selectedRole == 'courier') {
                                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                                      if (v.trim().length != 16) return 'Harus 16 digit';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _vehicleController,
                                  label: 'Detail Kendaraan',
                                  hintText: 'Contoh: Honda Beat BM 1234 DA',
                                  icon: Icons.motorcycle_outlined,
                                  validator: (v) {
                                    if (_selectedRole == 'courier' && (v == null || v.trim().isEmpty)) return 'Wajib diisi';
                                    return null;
                                  },
                                ),
                              ],
                              
                              const SizedBox(height: 24),
                              Text('Alamat Domisili', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 12),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedVillage,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                                    onChanged: (String? val) {
                                      if (val != null) setState(() => _selectedVillage = val);
                                    },
                                    items: villages.map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildTextField(
                                controller: _addressController,
                                label: 'Detail Alamat',
                                hintText: 'Jalan, Blok, RT/RW',
                                icon: Icons.home_outlined,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                              ),
                              
                              const SizedBox(height: 32),
                              
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return ElevatedButton(
                                    onPressed: auth.isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 56),
                                    ),
                                    child: auth.isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : const Text('Daftar Sekarang'),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Sudah punya akun? ', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13)),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text('Masuk', style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String roleId, IconData icon, String label) {
    final isSelected = _selectedRole == roleId;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefixIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppTheme.primaryColor, size: 18),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: _buildPrefixIcon(icon),
      ),
      validator: validator,
    );
  }
}
