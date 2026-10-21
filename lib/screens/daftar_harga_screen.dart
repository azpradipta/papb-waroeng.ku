import 'package:flutter/material.dart';
import '../data.dart';

class DaftarHargaScreen extends StatelessWidget {
  const DaftarHargaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Harga')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Daftar Harga Waroeng.Ku',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (daftarProduk.isEmpty)
              const Text(
                'Belum ada produk.',
                style: TextStyle(color: Colors.grey),
              ),
            for (Produk produk in daftarProduk)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('${produk.nama} (${produk.satuan})')),
                    const SizedBox(width: 8),
                    Text(
                      rupiah(produk.hargaJual),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Daftar harga siap dicetak')),
                  );
                },
                child: const Text('Cetak Daftar Harga'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
