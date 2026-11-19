import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/load_error.dart';
import '../widgets/period_filter.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  Laporan? _report;
  bool _started = false;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _until;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await AppServices.of(
        context,
      ).transactions.getReport(from: _from, until: _until);
      if (mounted && generation == _generation) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
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
        child: PeriodFilter(
          onChanged: (from, until) {
            _from = from;
            _until = until;
            _load();
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? LoadError(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Icon(
                      Icons.bar_chart,
                      size: 80,
                      color: Color(0xFFFF7A29),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Laporan Keuangan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _row(
                      'Jumlah Transaksi',
                      '${_report!.jumlahTransaksi} nota',
                    ),
                    _row('Barang Terjual', '${_report!.jumlahBarang} barang'),
                    _row('Total Penjualan', rupiah(_report!.penjualan)),
                    _row('Modal Barang Terjual', rupiah(_report!.modal)),
                    const Divider(),
                    _row('Laba Kotor', rupiah(_report!.laba)),
                    const SizedBox(height: 20),
                    const Text(
                      'Laba kotor belum dikurangi biaya operasional warung.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
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
