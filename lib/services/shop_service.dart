import 'package:supabase_flutter/supabase_flutter.dart';
import '../data.dart';
import 'api_exception.dart';

abstract interface class ShopService {
  Future<Toko> getStore();
  Future<Toko> updateStore(Toko store);
  Future<List<AkunKasir>> getCashiers();
  Future<void> createCashier({
    required String name,
    required String email,
    required String password,
  });
  Future<void> updateCashier({
    required String id,
    required String name,
    required bool active,
  });
  Future<void> resetCashierPassword(String id, String password);
}

class SupabaseShopService implements ShopService {
  final SupabaseClient client;
  const SupabaseShopService(this.client);

  @override
  Future<Toko> getStore() => apiCall(
    () async => Toko.fromMap(
      Map<String, dynamic>.from(await client.rpc('get_store') as Map),
    ),
  );

  @override
  Future<Toko> updateStore(Toko store) => apiCall(
    () async => Toko.fromMap(
      Map<String, dynamic>.from(
        await client.rpc(
              'update_store',
              params: {
                'p_name': store.nama,
                'p_address': store.alamat,
                'p_phone': store.telepon,
              },
            )
            as Map,
      ),
    ),
  );

  @override
  Future<List<AkunKasir>> getCashiers() => apiCall(() async {
    final rows = await client.rpc('list_cashiers') as List;
    return rows
        .map((row) => AkunKasir.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  });

  @override
  Future<void> updateCashier({
    required String id,
    required String name,
    required bool active,
  }) => apiCall(() async {
    await client.rpc(
      'update_cashier',
      params: {'p_id': id, 'p_name': name.trim(), 'p_active': active},
    );
  });

  @override
  Future<void> createCashier({
    required String name,
    required String email,
    required String password,
  }) => _manage({
    'action': 'create',
    'name': name.trim(),
    'email': email.trim(),
    'password': password,
  });

  @override
  Future<void> resetCashierPassword(String id, String password) =>
      _manage({'action': 'reset_password', 'id': id, 'password': password});

  Future<void> _manage(Map<String, dynamic> body) => apiCall(() async {
    await client.functions.invoke('manage-cashier', body: body);
  });
}
