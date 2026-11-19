import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import 'kasir_screen.dart';
import 'produk_screen.dart';
import 'riwayat_screen.dart';
import 'laporan_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final Profil profile;
  const MainScreen({super.key, required this.profile});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  bool _signingOut = false;
  final Map<Produk, int> _cart = {};
  late Profil _profile = widget.profile;

  Future<void> _settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(profile: _profile),
      ),
    );
    if (!mounted) return;
    try {
      final profile = await AppServices.of(context).auth.getProfile();
      if (mounted && profile != null) setState(() => _profile = profile);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Keranjang yang belum dibayar akan dikosongkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await AppServices.of(context).auth.signOut();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_profile.namaToko, overflow: TextOverflow.ellipsis),
            Text(
              '${_profile.nama} • ${_profile.role}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: _settings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _signingOut ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: switch (_index) {
        0 => KasirScreen(keranjang: _cart),
        1 => ProdukScreen(role: _profile.role),
        2 => const RiwayatScreen(),
        _ => const LaporanScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Produk',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Riwayat',
          ),
          if (_profile.isPemilik)
            const NavigationDestination(
              icon: Icon(Icons.bar_chart),
              label: 'Laporan',
            ),
        ],
      ),
    );
  }
}
