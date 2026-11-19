import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';

class DetailTransaksiScreen extends StatefulWidget {
  final Transaksi? transaksi;
  final String? id;
  const DetailTransaksiScreen({super.key, this.transaksi, this.id})
    : assert(transaksi != null || id != null);
  @override
  State<DetailTransaksiScreen> createState() => _DetailTransaksiScreenState();
}

class _DetailTransaksiScreenState extends State<DetailTransaksiScreen> {
  Transaksi? _transaction;
  bool _started = false;
  bool _loading = true;
  bool _documentBusy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _transaction = widget.transaksi;
    if (_transaction != null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transaction = await AppServices.of(
        context,
      ).transactions.getTransaction(widget.id!);
      if (mounted) {
        setState(() {
          _transaction = transaction;
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
    setState(() => _documentBusy = true);
    try {
      final documents = AppServices.of(context).documents;
      final bytes = await documents.receipt(_transaction!);
      if (share) {
        await documents.sharePdf(bytes, '${_transaction!.nomorNota}.pdf');
      } else {
        await documents.printPdf(bytes, _transaction!.nomorNota);
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
      if (mounted) setState(() => _documentBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail Transaksi')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? LoadError(message: _error!, onRetry: _load)
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Waroeng.Ku',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7A29),
                ),
              ),
              const SizedBox(height: 16),
              Text(_transaction!.nomorNota, textAlign: TextAlign.center),
              Text(
                formatTanggal(_transaction!.tanggal),
                textAlign: TextAlign.center,
              ),
              Text(
                'Kasir: ${_transaction!.kasir}',
                textAlign: TextAlign.center,
              ),
              const Divider(height: 32),
              for (final item in _transaction!.items)
                _row(
                  '${item.namaProduk}\n${item.jumlah} x ${rupiah(item.hargaJual)}',
                  rupiah(item.subtotal),
                ),
              const Divider(height: 32),
              _row('Total', rupiah(_transaction!.totalHarga)),
              _row('Bayar', rupiah(_transaction!.bayar)),
              _row('Kembalian', rupiah(_transaction!.kembalian)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _documentBusy ? null : () => _document(false),
                icon: const Icon(Icons.print),
                label: const Text('Cetak Nota'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _documentBusy ? null : () => _document(true),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Simpan / Bagikan PDF'),
              ),
            ],
          ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
