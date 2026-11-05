import 'package:flutter/material.dart';
import '../data.dart';
import '../services/product_service.dart';
import '../services/product_service_scope.dart';

class TambahStokScreen extends StatefulWidget {
  final Produk produk;

  const TambahStokScreen({super.key, required this.produk});

  @override
  State<TambahStokScreen> createState() => _TambahStokScreenState();
}

class _TambahStokScreenState extends State<TambahStokScreen> {
  String _jumlah = '';
  bool _sedangMenyimpan = false;

  Future<void> _simpan() async {
    int? jumlah = int.tryParse(_jumlah);
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah stok harus lebih dari 0')),
      );
      return;
    }
    setState(() {
      _sedangMenyimpan = true;
    });

    try {
      final service = ProductServiceScope.of(context);
      final hasil = await service.addProductStock(widget.produk, jumlah);
      widget.produk.salinDari(hasil);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } on ProductApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _sedangMenyimpan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Stok')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.add_box, size: 80, color: Color(0xFFFF7A29)),
            const SizedBox(height: 16),
            Text(
              widget.produk.nama,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Stok sekarang: ${widget.produk.stok} ${widget.produk.satuan}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              keyboardType: TextInputType.number,
              onChanged: (value) => _jumlah = value,
              decoration: const InputDecoration(
                labelText: 'Jumlah Stok Masuk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _sedangMenyimpan ? null : _simpan,
                child: Text(_sedangMenyimpan ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
