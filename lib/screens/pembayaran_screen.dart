import 'package:flutter/material.dart';
import '../data.dart';
import '../services/product_service.dart';
import '../services/product_service_scope.dart';

class PembayaranScreen extends StatefulWidget {
  final Map<Produk, int> keranjang;
  final int total;
  final String kasir;

  const PembayaranScreen({
    super.key,
    required this.keranjang,
    required this.total,
    required this.kasir,
  });

  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  int _uang = 0;
  bool _sedangMemproses = false;

  Future<void> _prosesPembayaran() async {
    if (_uang < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uang yang diterima kurang')),
      );
      return;
    }

    setState(() {
      _sedangMemproses = true;
    });

    try {
      final service = ProductServiceScope.of(context);
      final produkTerbaru = await service.decreaseProductStocks(
        widget.keranjang,
      );
      if (!mounted) {
        return;
      }
      _perbaruiStokLokal(produkTerbaru);
    } on ProductApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _sedangMemproses = false;
      });
      return;
    }

    List<ItemTransaksi> items = [];
    int totalLaba = 0;
    for (Produk produk in widget.keranjang.keys) {
      int jumlah = widget.keranjang[produk]!;
      int laba = (produk.hargaJual - produk.hargaModal) * jumlah;
      items.add(
        ItemTransaksi(
          namaProduk: produk.nama,
          hargaModal: produk.hargaModal,
          hargaJual: produk.hargaJual,
          jumlah: jumlah,
          subtotal: produk.hargaJual * jumlah,
          laba: laba,
        ),
      );
      totalLaba += laba;
    }

    int kembalian = _uang - widget.total;
    String nomorNota =
        'TRX-${(daftarTransaksi.length + 1).toString().padLeft(3, '0')}';
    daftarTransaksi.add(
      Transaksi(
        nomorNota: nomorNota,
        tanggal: DateTime.now(),
        kasir: widget.kasir,
        items: items,
        totalHarga: widget.total,
        totalLaba: totalLaba,
        bayar: _uang,
        kembalian: kembalian,
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pembayaran Berhasil'),
        content: Text(
          'No. Nota: $nomorNota\n'
          'Total: ${rupiah(widget.total)}\n'
          'Bayar: ${rupiah(_uang)}\n'
          'Kembalian: ${rupiah(kembalian)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context, true);
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _perbaruiStokLokal(List<Produk> produkTerbaru) {
    for (final terbaru in produkTerbaru) {
      for (final produk in widget.keranjang.keys) {
        if (produk.id == terbaru.id) {
          produk.salinDari(terbaru);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            for (Produk produk in widget.keranjang.keys)
              _baris(
                '${produk.nama} x ${widget.keranjang[produk]}',
                rupiah(produk.hargaJual * widget.keranjang[produk]!),
              ),
            const Divider(),
            _baris('Total', rupiah(widget.total)),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _uang = int.tryParse(value) ?? 0;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Uang Diterima',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _baris(
              'Kembalian',
              _uang >= widget.total ? rupiah(_uang - widget.total) : '-',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _sedangMemproses ? null : _prosesPembayaran,
                child: Text(
                  _sedangMemproses ? 'Memproses...' : 'Proses Pembayaran',
                ),
              ),
            ),
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
