import 'dart:async';
import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';
import '../widgets/period_filter.dart';
import 'detail_transaksi_screen.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});
  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final List<Transaksi> _transactions = [];
  bool _started = false;
  bool _loading = true;
  bool _hasMore = false;
  String? _error;
  String _search = '';
  DateTime? _from;
  DateTime? _until;
  Timer? _timer;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppServices.of(context).transactions.getTransactions(
        search: _search,
        from: _from,
        until: _until,
        offset: append ? _transactions.length : 0,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!append) _transactions.clear();
        _transactions.addAll(rows);
        _hasMore = rows.length == 50;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari nomor nota atau kasir',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _search = value.trim();
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 350), _load);
              },
            ),
            const SizedBox(height: 12),
            PeriodFilter(
              onChanged: (from, until) {
                _from = from;
                _until = until;
                _load();
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: _error != null
            ? LoadError(message: _error!, onRetry: _load)
            : _loading && _transactions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada transaksi pada periode ini.'),
                      ),
                    for (final transaction in _transactions)
                      Card(
                        child: ListTile(
                          title: Text(transaction.nomorNota),
                          subtitle: Text(
                            '${formatTanggal(transaction.tanggal)}\n${transaction.kasir} • ${rupiah(transaction.totalHarga)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetailTransaksiScreen(id: transaction.id),
                            ),
                          ),
                        ),
                      ),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (_hasMore && !_loading)
                      TextButton(
                        onPressed: () => _load(append: true),
                        child: const Text('Muat Lebih Banyak'),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}
