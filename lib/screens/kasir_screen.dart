import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';
import 'pembayaran_screen.dart';

class KasirScreen extends StatefulWidget {
  final Map<Produk, int> keranjang;
  const KasirScreen({super.key, required this.keranjang});
  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  List<Produk> _products = [];
  bool _started = false;
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await AppServices.of(context).products.getProducts();
      if (!mounted) return;
      final old = Map<Produk, int>.from(widget.keranjang);
      widget.keranjang.clear();
      for (final product in products) {
        for (final entry in old.entries) {
          if (entry.key.id == product.id) {
            widget.keranjang[product] = entry.value;
          }
        }
      }
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  int get _total => widget.keranjang.entries.fold(
    0,
    (sum, item) => sum + item.key.hargaJual * item.value,
  );

  void _change(Produk product, int delta) {
    final quantity = (widget.keranjang[product] ?? 0) + delta;
    if (quantity > product.stok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stok tidak mencukupi.')));
      return;
    }
    setState(() {
      if (quantity <= 0) {
        widget.keranjang.remove(product);
      } else {
        widget.keranjang[product] = quantity;
      }
    });
  }

  Future<void> _pay() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PembayaranScreen(
          keranjang: Map.from(widget.keranjang),
          total: _total,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) widget.keranjang.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return LoadError(message: _error!, onRetry: _load);
    final visible = _products
        .where((p) => p.nama.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Cari barang',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang produk',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada barang yang sesuai.'),
                  ),
                for (final product in visible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.nama,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${rupiah(product.hargaJual)} / ${product.satuan}',
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Stok: ${product.stok}',
                                  style: TextStyle(
                                    color: product.stok <= 5
                                        ? Colors.deepOrange
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Kurangi ${product.nama}',
                                onPressed: (widget.keranjang[product] ?? 0) == 0
                                    ? null
                                    : () => _change(product, -1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${widget.keranjang[product] ?? 0}'),
                              IconButton(
                                tooltip: 'Tambah ${product.nama}',
                                onPressed:
                                    (widget.keranjang[product] ?? 0) >=
                                        product.stok
                                    ? null
                                    : () => _change(product, 1),
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Color(0xFFFF7A29),
                                ),
                              ),
                            ],
                          ),
                          if ((widget.keranjang[product] ?? 0) > product.stok)
                            const Text(
                              'Jumlah melebihi stok terbaru. Kurangi barang.',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${rupiah(_total)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed:
                      widget.keranjang.isEmpty ||
                          widget.keranjang.entries.any(
                            (e) => e.value > e.key.stok,
                          )
                      ? null
                      : _pay,
                  child: const Text('Bayar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
