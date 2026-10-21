import 'package:flutter/material.dart';
import '../data.dart';
import 'daftar_harga_screen.dart';
import 'detail_produk_screen.dart';
import 'form_produk_screen.dart';

class ProdukScreen extends StatefulWidget {
  final String role;

  const ProdukScreen({super.key, required this.role});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  void _buka(Widget halaman) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => halaman),
    );
    // Setelah kembali, tampilan diperbarui karena data produk bisa berubah.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _buka(const DaftarHargaScreen()),
                    child: const Text('Daftar Harga'),
                  ),
                ),
                // Tombol Tambah Produk hanya untuk Pemilik.
                if (widget.role == 'Pemilik') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _buka(const FormProdukScreen()),
                      child: const Text('Tambah Produk'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (daftarProduk.isEmpty)
              const Text(
                'Belum ada produk.',
                style: TextStyle(color: Colors.grey),
              ),
            for (Produk produk in daftarProduk) _itemProduk(produk),
          ],
        ),
      ),
    );
  }

  Widget _itemProduk(Produk produk) {
    return GestureDetector(
      onTap: () => _buka(DetailProdukScreen(role: widget.role, produk: produk)),
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
                    produk.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rupiah(produk.hargaJual),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stok: ${produk.stok} ${produk.satuan}',
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
