import 'package:flutter/material.dart';
import '../data.dart';

class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    int totalPenjualan = 0;
    int totalLaba = 0;
    for (Transaksi transaksi in daftarTransaksi) {
      totalPenjualan += transaksi.totalHarga;
      totalLaba += transaksi.totalLaba;
    }
    int totalModal = totalPenjualan - totalLaba;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.bar_chart, size: 80, color: Color(0xFFFF7A29)),
            const SizedBox(height: 16),
            const Text(
              'Laporan Keuangan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ringkasan dari semua transaksi yang sudah tercatat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _baris('Jumlah Transaksi', '${daftarTransaksi.length}'),
            _baris('Total Penjualan', rupiah(totalPenjualan)),
            _baris('Total Modal', rupiah(totalModal)),
            const Divider(),
            _baris('Laba Kotor', rupiah(totalLaba)),
          ],
        ),
      ),
    );
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(nilai, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
