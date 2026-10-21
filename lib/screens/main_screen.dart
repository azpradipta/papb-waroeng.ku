import 'package:flutter/material.dart';
import 'kasir_screen.dart';
import 'produk_screen.dart';
import 'riwayat_screen.dart';
import 'laporan_screen.dart';

class MainScreen extends StatefulWidget {
  final String role;

  const MainScreen({super.key, required this.role});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Menu Laporan hanya muncul untuk Pemilik.
    bool isPemilik = widget.role == 'Pemilik';

    List<Widget> pages = [
      KasirScreen(role: widget.role),
      ProdukScreen(role: widget.role),
      const RiwayatScreen(),
      if (isPemilik) const LaporanScreen(),
    ];

    return Scaffold(
      // Halaman dibuat ulang setiap pindah menu, jadi data yang tampil selalu terbaru.
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFF7A29).withValues(alpha: 0.2),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFFFF7A29)),
            label: 'Kasir',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Color(0xFFFF7A29)),
            label: 'Produk',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFFFF7A29)),
            label: 'Riwayat',
          ),
          if (isPemilik)
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart, color: Color(0xFFFF7A29)),
              label: 'Laporan',
            ),
        ],
      ),
    );
  }
}
