import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';

// Dipakai untuk Tambah Produk dan Edit Produk.
// Kalau produk null berarti tambah, kalau ada isinya berarti edit.
class FormProdukScreen extends StatefulWidget {
  final Produk? produk;

  const FormProdukScreen({super.key, this.produk});

  @override
  State<FormProdukScreen> createState() => _FormProdukScreenState();
}

class _FormProdukScreenState extends State<FormProdukScreen> {
  String _nama = '';
  String _hargaModal = '';
  String _hargaJual = '';
  String _stok = '';
  String _satuan = '';
  bool _sedangMenyimpan = false;

  @override
  void initState() {
    super.initState();
    Produk? produk = widget.produk;
    if (produk != null) {
      _nama = produk.nama;
      _hargaModal = produk.hargaModal.toString();
      _hargaJual = produk.hargaJual.toString();
      _stok = produk.stok.toString();
      _satuan = produk.satuan;
    }
  }

  Future<void> _simpan() async {
    if (_sedangMenyimpan) return;
    String nama = _nama.trim();
    String satuan = _satuan.trim();
    int? hargaModal = int.tryParse(_hargaModal);
    int? hargaJual = int.tryParse(_hargaJual);
    int? stok = int.tryParse(_stok);

    if (nama.isEmpty ||
        satuan.isEmpty ||
        hargaModal == null ||
        hargaJual == null ||
        stok == null ||
        hargaModal < 0 ||
        hargaJual < 0 ||
        stok < 0 ||
        nama.length > 100 ||
        satuan.length > 20 ||
        hargaModal > 2147483647 ||
        hargaJual > 2147483647 ||
        stok > 2147483647) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua data harus diisi dengan benar')),
      );
      return;
    }

    setState(() {
      _sedangMenyimpan = true;
    });

    final produkLama = widget.produk;
    final produkBaru = Produk(
      id: produkLama?.id,
      nama: nama,
      hargaModal: hargaModal,
      hargaJual: hargaJual,
      stok: stok,
      satuan: satuan,
      dibuatPada: produkLama?.dibuatPada,
    );

    try {
      final service = AppServices.of(context).products;
      if (produkLama == null) {
        await service.createProduct(produkBaru);
      } else {
        final hasil = await service.updateProduct(produkBaru);
        produkLama.salinDari(hasil);
      }
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
        _sedangMenyimpan = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String judul = widget.produk == null ? 'Tambah Produk' : 'Edit Produk';

    return PopScope(
      canPop: !_sedangMenyimpan,
      child: Scaffold(
        appBar: AppBar(title: Text(judul)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextFormField(
                initialValue: _nama,
                enabled: !_sedangMenyimpan,
                maxLength: 100,
                onChanged: (value) => _nama = value,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _hargaModal,
                enabled: !_sedangMenyimpan,
                keyboardType: TextInputType.number,
                onChanged: (value) => _hargaModal = value,
                decoration: const InputDecoration(
                  labelText: 'Harga Modal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _hargaJual,
                enabled: !_sedangMenyimpan,
                keyboardType: TextInputType.number,
                onChanged: (value) => _hargaJual = value,
                decoration: const InputDecoration(
                  labelText: 'Harga Jual',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.produk == null)
                TextFormField(
                  initialValue: _stok,
                  enabled: !_sedangMenyimpan,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _stok = value,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _satuan,
                enabled: !_sedangMenyimpan,
                maxLength: 20,
                onChanged: (value) => _satuan = value,
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  hintText: 'pcs, bungkus, botol',
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
      ),
    );
  }
}
