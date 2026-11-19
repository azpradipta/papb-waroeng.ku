import 'package:supabase_flutter/supabase_flutter.dart';
import '../data.dart';
import 'api_exception.dart';

abstract interface class TransactionService {
  Future<Transaksi> checkout({
    required String requestId,
    required Map<Produk, int> items,
    required int cash,
    required int expectedTotal,
  });
  Future<List<Transaksi>> getTransactions({
    String search = '',
    DateTime? from,
    DateTime? until,
    int offset = 0,
  });
  Future<Transaksi> getTransaction(String id);
  Future<Laporan> getReport({DateTime? from, DateTime? until});
}

class SupabaseTransactionService implements TransactionService {
  final SupabaseClient client;
  const SupabaseTransactionService(this.client);

  @override
  Future<Transaksi> checkout({
    required String requestId,
    required Map<Produk, int> items,
    required int cash,
    required int expectedTotal,
  }) => apiCall(() async {
    if (items.isEmpty || items.keys.any((p) => p.id == null)) {
      throw const ApiException('Keranjang tidak valid. Muat ulang produk.');
    }
    final data = await client.rpc(
      'checkout',
      params: {
        'p_request_id': requestId,
        'p_cash': cash,
        'p_expected_total': expectedTotal,
        'p_items': [
          for (final entry in items.entries)
            {
              'product_id': entry.key.id,
              'qty': entry.value,
              'expected_price': entry.key.hargaJual,
            },
        ],
      },
    );
    return Transaksi.fromMap(Map<String, dynamic>.from(data as Map));
  });

  @override
  Future<List<Transaksi>> getTransactions({
    String search = '',
    DateTime? from,
    DateTime? until,
    int offset = 0,
  }) => apiCall(() async {
    final data = await client.rpc(
      'list_transactions',
      params: {
        'p_search': search.trim(),
        'p_from': from?.toUtc().toIso8601String(),
        'p_until': until?.toUtc().toIso8601String(),
        'p_offset': offset,
      },
    );
    return [
      for (final row in data as List)
        Transaksi.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  });

  @override
  Future<Transaksi> getTransaction(String id) => apiCall(() async {
    final data = await client.rpc('get_transaction', params: {'p_id': id});
    return Transaksi.fromMap(Map<String, dynamic>.from(data as Map));
  });

  @override
  Future<Laporan> getReport({DateTime? from, DateTime? until}) =>
      apiCall(() async {
        final data = await client.rpc(
          'get_report',
          params: {
            'p_from': from?.toUtc().toIso8601String(),
            'p_until': until?.toUtc().toIso8601String(),
          },
        );
        return Laporan.fromMap(Map<String, dynamic>.from(data as Map));
      });
}
