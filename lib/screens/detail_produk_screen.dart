import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import 'form_produk_screen.dart';
import 'tambah_stok_screen.dart';

class DetailProdukScreen extends StatefulWidget {
  final String role;
  final Produk produk;

  const DetailProdukScreen({
    super.key,
    required this.role,
    required this.produk,
  });

  @override
  State<DetailProdukScreen> createState() => _DetailProdukScreenState();
}

class _DetailProdukScreenState extends State<DetailProdukScreen> {
  bool _sedangMenghapus = false;

  void _buka(Widget halaman) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => halaman),
    );
    if (mounted) setState(() {});
  }

  Future<void> _hapusProduk() async {
    if (_sedangMenghapus) return;
    final dikonfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text(
          '${widget.produk.nama} akan dihapus dari katalog. Nota lama tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (dikonfirmasi != true || !mounted) {
      return;
    }

    setState(() {
      _sedangMenghapus = true;
    });

    try {
      final service = AppServices.of(context).products;
      await service.deleteProduct(widget.produk);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _sedangMenghapus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Produk produk = widget.produk;
    bool isPemilik = widget.role == 'Pemilik';

    return PopScope(
      canPop: !_sedangMenghapus,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detail Produk')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.inventory_2, size: 80, color: Color(0xFFFF7A29)),
              const SizedBox(height: 16),
              Text(
                produk.nama,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _baris('Harga Jual', rupiah(produk.hargaJual)),
              // Harga modal hanya boleh dilihat Pemilik.
              if (isPemilik) _baris('Harga Modal', rupiah(produk.hargaModal)),
              _baris('Stok', '${produk.stok} ${produk.satuan}'),
              const SizedBox(height: 24),
              // Edit, tambah stok, dan hapus hanya untuk Pemilik.
              if (isPemilik) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _sedangMenghapus
                        ? null
                        : () => _buka(FormProdukScreen(produk: produk)),
                    child: const Text('Edit Produk'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _sedangMenghapus
                        ? null
                        : () => _buka(TambahStokScreen(produk: produk)),
                    child: const Text('Tambah Stok'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _sedangMenghapus ? null : _hapusProduk,
                  child: Text(
                    _sedangMenghapus ? 'Menghapus...' : 'Hapus Produk',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ] else
                const Text(
                  'Perubahan produk hanya dapat dilakukan oleh Pemilik.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
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
          Flexible(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
