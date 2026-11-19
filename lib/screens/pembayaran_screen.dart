import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import 'detail_transaksi_screen.dart';

class PembayaranScreen extends StatefulWidget {
  final Map<Produk, int> keranjang;
  final int total;
  const PembayaranScreen({
    super.key,
    required this.keranjang,
    required this.total,
  });
  @override
  State<PembayaranScreen> createState() => _PembayaranScreenState();
}

class _PembayaranScreenState extends State<PembayaranScreen> {
  // ID ini tetap sama saat retry: backend hanya membuat satu nota.
  final _requestId = const Uuid().v4();
  final _cash = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_busy) return;
    final cash = int.tryParse(_cash.text);
    if (cash == null || cash < widget.total || cash > 2147483647) {
      setState(
        () => _error =
            'Isi uang pembayaran yang cukup, maksimal Rp 2.147.483.647.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transaction = await AppServices.of(context).transactions.checkout(
        requestId: _requestId,
        items: widget.keranjang,
        cash: cash,
        expectedTotal: widget.total,
      );
      if (!mounted) return;
      final viewReceipt = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pembayaran Berhasil'),
          content: Text(
            'No. Nota: ${transaction.nomorNota}\n'
            'Total: ${rupiah(transaction.totalHarga)}\n'
            'Bayar: ${rupiah(transaction.bayar)}\n'
            'Kembalian: ${rupiah(transaction.kembalian)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lihat Nota'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (viewReceipt == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailTransaksiScreen(transaksi: transaction),
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash = int.tryParse(_cash.text) ?? 0;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pembayaran')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final item in widget.keranjang.entries)
              _row(
                '${item.key.nama} x ${item.value}',
                rupiah(item.key.hargaJual * item.value),
              ),
            const Divider(),
            _row('Total', rupiah(widget.total)),
            const SizedBox(height: 20),
            TextField(
              key: const Key('cash-paid'),
              controller: _cash,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(labelText: 'Uang Diterima'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final amount in [widget.total, 20000, 50000, 100000])
                  ActionChip(
                    label: Text(
                      amount == widget.total ? 'Uang Pas' : rupiah(amount),
                    ),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _cash.text = amount.toString()),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _row(
              cash >= widget.total ? 'Kembalian' : 'Kekurangan',
              rupiah((cash - widget.total).abs()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _pay,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_busy ? 'Memproses...' : 'Proses Pembayaran'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
