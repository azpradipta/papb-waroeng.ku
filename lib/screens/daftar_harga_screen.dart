import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';

class DaftarHargaScreen extends StatefulWidget {
  const DaftarHargaScreen({super.key});
  @override
  State<DaftarHargaScreen> createState() => _DaftarHargaScreenState();
}

class _DaftarHargaScreenState extends State<DaftarHargaScreen> {
  List<Produk> _products = [];
  bool _started = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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

  Future<void> _document(bool share) async {
    setState(() => _busy = true);
    try {
      final services = AppServices.of(context);
      final documents = services.documents;
      final store = await services.shop.getStore();
      final bytes = await documents.priceList(_products, storeName: store.nama);
      if (share) {
        await documents.sharePdf(bytes, 'daftar-harga-waroeng-ku.pdf');
      } else {
        await documents.printPdf(bytes, 'Daftar Harga ${store.nama}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dokumen belum dapat dibuka. Coba simpan PDF atau cetak lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Daftar Harga'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang daftar harga',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? LoadError(message: _error!, onRetry: _load)
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Daftar Harga Waroeng.Ku',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_products.isEmpty) const Text('Belum ada produk.'),
              for (final product in _products)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.nama),
                  subtitle: Text('Per ${product.satuan}'),
                  trailing: Text(rupiah(product.hargaJual)),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy || _products.isEmpty
                    ? null
                    : () => _document(false),
                icon: const Icon(Icons.print),
                label: const Text('Cetak Daftar Harga'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy || _products.isEmpty
                    ? null
                    : () => _document(true),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Simpan / Bagikan PDF'),
              ),
            ],
          ),
  );
}
