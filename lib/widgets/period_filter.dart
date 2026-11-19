import 'package:flutter/material.dart';
import '../data.dart';

class PeriodFilter extends StatefulWidget {
  final void Function(DateTime? from, DateTime? until) onChanged;
  const PeriodFilter({super.key, required this.onChanged});
  @override
  State<PeriodFilter> createState() => _PeriodFilterState();
}

class _PeriodFilterState extends State<PeriodFilter> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  String _value = 'Semua';
  String? _rangeLabel;

  Future<void> _select(String value) async {
    if (value == 'Rentang tanggal') {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year, now.month, now.day),
        helpText: 'Pilih periode laporan',
      );
      if (!mounted) return;
      if (range == null) {
        _fieldKey.currentState?.didChange(_value);
        return;
      }
      setState(() {
        _value = value;
        _rangeLabel =
            '${formatTanggal(range.start).split(' ').first} — ${formatTanggal(range.end).split(' ').first}';
      });
      widget.onChanged(
        range.start,
        DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
    } else {
      setState(() {
        _value = value;
        _rangeLabel = null;
      });
      widget.onChanged(awalPeriode(value), null);
    }
  }

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: _fieldKey,
    value: _value,
    isExpanded: true,
    decoration: InputDecoration(labelText: 'Periode', helperText: _rangeLabel),
    items: [
      for (final value in [
        'Semua',
        'Hari ini',
        '7 hari terakhir',
        'Bulan ini',
        'Rentang tanggal',
      ])
        DropdownMenuItem(value: value, child: Text(value)),
    ],
    onChanged: (value) {
      if (value != null) _select(value);
    },
  );
}
