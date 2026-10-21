import 'package:flutter/material.dart';
import '../data.dart';
import 'detail_transaksi_screen.dart';

class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (daftarTransaksi.isEmpty)
              const Text(
                'Belum ada transaksi.',
                style: TextStyle(color: Colors.grey),
              ),
            // Transaksi terbaru ditampilkan paling atas.
            for (Transaksi transaksi in daftarTransaksi.reversed)
              _itemTransaksi(context, transaksi),
          ],
        ),
      ),
    );
  }

  Widget _itemTransaksi(BuildContext context, Transaksi transaksi) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailTransaksiScreen(transaksi: transaksi),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    transaksi.nomorNota,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rupiah(transaksi.totalHarga),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatTanggal(transaksi.tanggal)} - ${transaksi.kasir}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
