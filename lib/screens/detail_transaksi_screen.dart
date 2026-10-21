import 'package:flutter/material.dart';
import '../data.dart';

// Menampilkan nota dari satu transaksi.
class DetailTransaksiScreen extends StatelessWidget {
  final Transaksi transaksi;

  const DetailTransaksiScreen({super.key, required this.transaksi});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Waroeng.Ku',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7A29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              transaksi.nomorNota,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              formatTanggal(transaksi.tanggal),
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Kasir: ${transaksi.kasir}',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 32),
            for (ItemTransaksi item in transaksi.items)
              _baris(
                '${item.namaProduk}\n${item.jumlah} x ${rupiah(item.hargaJual)}',
                rupiah(item.subtotal),
              ),
            const Divider(height: 32),
            _baris('Total', rupiah(transaksi.totalHarga)),
            _baris('Bayar', rupiah(transaksi.bayar)),
            _baris('Kembalian', rupiah(transaksi.kembalian)),
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
