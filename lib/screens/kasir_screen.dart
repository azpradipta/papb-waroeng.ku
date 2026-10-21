import 'package:flutter/material.dart';
import '../data.dart';
import 'login_screen.dart';
import 'pembayaran_screen.dart';

class KasirScreen extends StatefulWidget {
  final String role;

  const KasirScreen({super.key, required this.role});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  // Keranjang berisi produk yang dibeli dan jumlahnya.
  final Map<Produk, int> _keranjang = {};

  void _tambah(Produk produk) {
    int jumlah = _keranjang[produk] ?? 0;
    if (jumlah >= produk.stok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${produk.nama} tidak cukup')),
      );
      return;
    }
    setState(() {
      _keranjang[produk] = jumlah + 1;
    });
  }

  void _kurang(Produk produk) {
    int jumlah = _keranjang[produk] ?? 0;
    setState(() {
      if (jumlah <= 1) {
        _keranjang.remove(produk);
      } else {
        _keranjang[produk] = jumlah - 1;
      }
    });
  }

  int _total() {
    int total = 0;
    for (Produk produk in _keranjang.keys) {
      total += produk.hargaJual * _keranjang[produk]!;
    }
    return total;
  }

  void _bayar() async {
    bool? berhasil = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PembayaranScreen(
          keranjang: _keranjang,
          total: _total(),
          kasir: widget.role,
        ),
      ),
    );
    // Keranjang dikosongkan kalau pembayaran berhasil.
    if (berhasil == true) {
      setState(() {
        _keranjang.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (daftarProduk.isEmpty)
                    const Text(
                      'Belum ada produk.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  for (Produk produk in daftarProduk) _itemProduk(produk),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${rupiah(_total())}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _keranjang.isEmpty ? null : _bayar,
                  child: const Text('Bayar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemProduk(Produk produk) {
    int jumlah = _keranjang[produk] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
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
              Text(rupiah(produk.hargaJual)),
              const SizedBox(width: 8),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Stok: ${produk.stok} ${produk.satuan}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              IconButton(
                onPressed: jumlah == 0 ? null : () => _kurang(produk),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$jumlah',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => _tambah(produk),
                icon: const Icon(Icons.add_circle, color: Color(0xFFFF7A29)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
