import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';
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
  List<Produk> _products = [];
  bool _started = false;
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'Semua';

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
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return LoadError(message: _error!, onRetry: _load);
    final visible = _products
        .where(
          (p) =>
              p.nama.toLowerCase().contains(_search.toLowerCase()) &&
              (_filter == 'Semua' ||
                  (_filter == 'Habis'
                      ? p.stok == 0
                      : p.stok > 0 && p.stok <= 5)),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _open(const DaftarHargaScreen()),
                      child: const Text('Daftar Harga'),
                    ),
                  ),
                  if (widget.role == 'Pemilik') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _open(const FormProdukScreen()),
                        child: const Text('Tambah Produk'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _search = v.trim()),
                decoration: const InputDecoration(
                  labelText: 'Cari produk',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['Semua', 'Menipis', 'Habis'])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Produk tidak ditemukan.'),
                  ),
                for (final p in visible)
                  Card(
                    child: ListTile(
                      title: Text(p.nama),
                      subtitle: Text(
                        '${rupiah(p.hargaJual)} / ${p.satuan}\nStok: ${p.stok}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        DetailProdukScreen(role: widget.role, produk: p),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
