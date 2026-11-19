import 'package:supabase_flutter/supabase_flutter.dart';
import '../data.dart';
import 'api_exception.dart';

abstract interface class ProductService {
  Future<List<Produk>> getProducts();
  Future<Produk> createProduct(Produk produk);
  Future<Produk> updateProduct(Produk produk);
  Future<Produk> addProductStock(Produk produk, int jumlah);
  Future<void> deleteProduct(Produk produk);
}

class SupabaseProductService implements ProductService {
  final SupabaseClient client;
  const SupabaseProductService(this.client);

  @override
  Future<List<Produk>> getProducts() => apiCall(() async {
    // Paging menghindari batas default 1.000 baris pada Data API.
    final products = <Produk>[];
    int offset = 0;
    while (true) {
      final rows =
          await client.rpc('get_products', params: {'p_offset': offset})
              as List;
      products.addAll(
        rows.map(
          (row) => Produk.fromMap(Map<String, dynamic>.from(row as Map)),
        ),
      );
      if (rows.length < 200) break;
      offset += rows.length;
    }
    return products;
  });

  @override
  Future<Produk> createProduct(Produk produk) => _write('create_product', {
    'p_name': produk.nama,
    'p_cost': produk.hargaModal,
    'p_price': produk.hargaJual,
    'p_stock': produk.stok,
    'p_unit': produk.satuan,
  });

  @override
  Future<Produk> updateProduct(Produk produk) => _write('update_product', {
    'p_id': produk.id,
    'p_name': produk.nama,
    'p_cost': produk.hargaModal,
    'p_price': produk.hargaJual,
    'p_unit': produk.satuan,
  });

  @override
  Future<Produk> addProductStock(Produk produk, int jumlah) => _write(
    'add_product_stock',
    {'p_product_id': produk.id, 'p_quantity': jumlah},
  );

  Future<Produk> _write(String name, Map<String, dynamic> params) =>
      apiCall(() async {
        final data = await client.rpc(name, params: params);
        return Produk.fromMap(Map<String, dynamic>.from(data as Map));
      });

  @override
  Future<void> deleteProduct(Produk produk) => apiCall(() async {
    await client.rpc('delete_product', params: {'p_id': produk.id});
  });
}
