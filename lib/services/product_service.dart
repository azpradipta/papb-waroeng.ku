import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';

abstract interface class ProductService {
  Future<List<Produk>> getProducts();

  Future<Produk> createProduct(Produk produk);

  Future<Produk> updateProduct(Produk produk);

  Future<Produk> addProductStock(Produk produk, int jumlah);

  Future<List<Produk>> decreaseProductStocks(Map<Produk, int> items);

  Future<void> deleteProduct(Produk produk);
}

class ProductApiException implements Exception {
  final String message;

  const ProductApiException(this.message);

  @override
  String toString() => message;
}

class SupabaseProductService implements ProductService {
  static const String _columns =
      'id,name,cost_price,selling_price,stock,unit,created_at';

  final SupabaseClient _client;

  const SupabaseProductService(this._client);

  @override
  Future<List<Produk>> getProducts() async {
    try {
      final data = await _client
          .from('products')
          .select(_columns)
          .order('name');
      return _productList(data);
    } on PostgrestException catch (error) {
      throw _apiError('mengambil produk', error);
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat mengambil produk. Periksa koneksi internet.',
      );
    }
  }

  @override
  Future<Produk> createProduct(Produk produk) async {
    try {
      final data = await _client
          .from('products')
          .insert(produk.toInsertMap())
          .select(_columns)
          .single();
      return Produk.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (error) {
      throw _apiError('menambah produk', error);
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat menambah produk. Periksa koneksi internet.',
      );
    }
  }

  @override
  Future<Produk> updateProduct(Produk produk) async {
    final id = _requiredId(produk);
    try {
      final data = await _client
          .from('products')
          .update(produk.toUpdateMap())
          .eq('id', id)
          .select(_columns)
          .single();
      return Produk.fromMap(Map<String, dynamic>.from(data));
    } on PostgrestException catch (error) {
      throw _apiError('mengubah produk', error);
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat mengubah produk. Periksa koneksi internet.',
      );
    }
  }

  @override
  Future<Produk> addProductStock(Produk produk, int jumlah) async {
    final id = _requiredId(produk);
    if (jumlah <= 0) {
      throw const ProductApiException('Jumlah stok harus lebih dari 0.');
    }

    try {
      final data = await _client.rpc(
        'add_product_stock',
        params: {'p_product_id': id, 'p_quantity': jumlah},
      );
      return Produk.fromMap(_singleMap(data));
    } on PostgrestException catch (error) {
      throw _apiError('menambah stok', error);
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat menambah stok. Periksa koneksi internet.',
      );
    }
  }

  @override
  Future<List<Produk>> decreaseProductStocks(Map<Produk, int> items) async {
    if (items.isEmpty) {
      throw const ProductApiException('Keranjang masih kosong.');
    }

    final payload = <Map<String, int>>[];
    for (final entry in items.entries) {
      payload.add({
        'product_id': _requiredId(entry.key),
        'quantity': entry.value,
      });
    }

    try {
      final data = await _client.rpc(
        'decrease_product_stocks',
        params: {'p_items': payload},
      );
      return _productList(data);
    } on PostgrestException catch (error) {
      throw _apiError('mengurangi stok', error);
    } on ProductApiException {
      rethrow;
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat memproses stok penjualan. Periksa koneksi internet.',
      );
    }
  }

  @override
  Future<void> deleteProduct(Produk produk) async {
    final id = _requiredId(produk);
    try {
      await _client.from('products').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const ProductApiException(
          'Produk tidak dapat dihapus karena sudah memiliki riwayat transaksi.',
        );
      }
      throw _apiError('menghapus produk', error);
    } catch (_) {
      throw const ProductApiException(
        'Tidak dapat menghapus produk. Periksa koneksi internet.',
      );
    }
  }

  int _requiredId(Produk produk) {
    final id = produk.id;
    if (id == null) {
      throw const ProductApiException(
        'Produk belum memiliki ID dari Supabase.',
      );
    }
    return id;
  }

  List<Produk> _productList(Object? data) {
    if (data is! List) {
      throw const ProductApiException('Format respons produk tidak sesuai.');
    }
    return data
        .map((item) => Produk.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Map<String, dynamic> _singleMap(Object? data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List && data.length == 1 && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    throw const ProductApiException('Format respons produk tidak sesuai.');
  }

  ProductApiException _apiError(String operasi, PostgrestException error) {
    if (error.code == '23514') {
      return const ProductApiException(
        'Harga dan stok tidak boleh bernilai negatif.',
      );
    }
    if (error.code == 'P0001') {
      return ProductApiException(error.message);
    }
    return ProductApiException('Gagal $operasi: ${error.message}');
  }
}
