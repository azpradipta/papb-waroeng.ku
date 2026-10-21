import 'package:flutter/material.dart';
import '../data.dart';

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

  void _simpan() {
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
        stok < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua data harus diisi dengan benar')),
      );
      return;
    }

    Produk? produk = widget.produk;
    if (produk == null) {
      daftarProduk.add(
        Produk(
          nama: nama,
          hargaModal: hargaModal,
          hargaJual: hargaJual,
          stok: stok,
          satuan: satuan,
        ),
      );
    } else {
      produk.nama = nama;
      produk.hargaModal = hargaModal;
      produk.hargaJual = hargaJual;
      produk.stok = stok;
      produk.satuan = satuan;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String judul = widget.produk == null ? 'Tambah Produk' : 'Edit Produk';

    return Scaffold(
      appBar: AppBar(title: Text(judul)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextFormField(
              initialValue: _nama,
              onChanged: (value) => _nama = value,
              decoration: const InputDecoration(
                labelText: 'Nama Produk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _hargaModal,
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
              keyboardType: TextInputType.number,
              onChanged: (value) => _hargaJual = value,
              decoration: const InputDecoration(
                labelText: 'Harga Jual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _stok,
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
                onPressed: _simpan,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
