import 'dart:async';
import 'dart:typed_data';
import 'package:waroeng_ku/data.dart';
import 'package:waroeng_ku/services/api_exception.dart';
import 'package:waroeng_ku/services/auth_service.dart';
import 'package:waroeng_ku/services/product_service.dart';
import 'package:waroeng_ku/services/transaction_service.dart';
import 'package:waroeng_ku/services/document_service.dart';
import 'package:waroeng_ku/services/shop_service.dart';

class FakeAuth implements AuthService {
  final events = StreamController<void>.broadcast();
  Profil? profile;
  String? changedPassword;
  AccountDeletionRequest? deletionRequest;
  Completer<void>? deletionPending;
  bool failDeletion = false;
  int deletionCalls = 0;
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<Profil?> getProfile() async => profile;
  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'valid123') {
      throw const ApiException('Email atau password salah.');
    }
    profile = Profil(
      id: email,
      nama: email.startsWith('owner') ? 'Bu Sri' : 'Dina',
      role: email.startsWith('owner') ? 'Pemilik' : 'Kasir',
      tokoId: 'store-1',
      namaToko: 'Warung Uji',
    );
    events.add(null);
  }

  @override
  Future<void> signOut() async {
    profile = null;
    events.add(null);
  }

  @override
  Future<void> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) async {
    profile = Profil(
      id: email,
      nama: name,
      role: 'Pemilik',
      tokoId: 'store-1',
      namaToko: storeName,
    );
    events.add(null);
  }

  @override
  Future<void> changePassword(String password) async {
    changedPassword = password;
  }

  @override
  Future<AccountDeletionRequest?> getAccountDeletionRequest() async =>
      deletionRequest;

  @override
  Future<AccountDeletionRequest> requestAccountDeletion() async {
    deletionCalls++;
    if (deletionPending != null) await deletionPending!.future;
    if (failDeletion) throw const ApiException('Koneksi terputus. Coba lagi.');
    return deletionRequest ??= AccountDeletionRequest(
      id: 'deletion-1',
      status: 'pending',
      requestedAt: DateTime.utc(2026, 11, 20),
    );
  }
}

class FakeShop implements ShopService {
  final FakeAuth auth;
  Toko store = const Toko(id: 'store-1', nama: 'Warung Uji');
  final rows = <AkunKasir>[];
  String? resetId;
  String? resetPassword;
  FakeShop(this.auth);
  @override
  Future<Toko> getStore() async => store;
  @override
  Future<Toko> updateStore(Toko value) async {
    store = value;
    final profile = auth.profile!;
    auth.profile = Profil(
      id: profile.id,
      nama: profile.nama,
      role: profile.role,
      tokoId: store.id,
      namaToko: store.nama,
    );
    return store;
  }

  @override
  Future<List<AkunKasir>> getCashiers() async => rows.toList();
  @override
  Future<void> createCashier({
    required String name,
    required String email,
    required String password,
  }) async {
    if (rows.any((row) => row.email == email)) {
      throw const ApiException('Email sudah digunakan.');
    }
    rows.add(
      AkunKasir(
        id: 'cashier-${rows.length}',
        nama: name,
        email: email,
        aktif: true,
      ),
    );
  }

  @override
  Future<void> updateCashier({
    required String id,
    required String name,
    required bool active,
  }) async {
    final index = rows.indexWhere((row) => row.id == id);
    rows[index] = AkunKasir(
      id: id,
      nama: name,
      email: rows[index].email,
      aktif: active,
    );
  }

  @override
  Future<void> resetCashierPassword(String id, String password) async {
    resetId = id;
    resetPassword = password;
  }
}

class FakeProducts implements ProductService {
  bool failLoad = false;
  Completer<void>? savePending;
  final rows = [
    Produk(
      id: 1,
      nama: 'Beras 1 kg',
      hargaModal: 12000,
      hargaJual: 15000,
      stok: 10,
      satuan: 'bungkus',
    ),
    Produk(
      id: 2,
      nama: 'Minyak Goreng',
      hargaModal: 15000,
      hargaJual: 18000,
      stok: 5,
      satuan: 'botol',
    ),
  ];
  int nextId = 3;
  Produk clone(Produk p) => Produk(
    id: p.id,
    nama: p.nama,
    hargaModal: p.hargaModal,
    hargaJual: p.hargaJual,
    stok: p.stok,
    satuan: p.satuan,
  );
  @override
  Future<List<Produk>> getProducts() async {
    if (failLoad) throw const ApiException('Koneksi terputus.');
    return rows.map(clone).toList();
  }

  @override
  Future<Produk> createProduct(Produk p) async {
    if (savePending != null) await savePending!.future;
    p.id = nextId++;
    rows.add(clone(p));
    return clone(p);
  }

  @override
  Future<Produk> updateProduct(Produk p) async {
    final saved = rows.firstWhere((r) => r.id == p.id);
    saved.nama = p.nama;
    saved.hargaModal = p.hargaModal;
    saved.hargaJual = p.hargaJual;
    saved.satuan = p.satuan;
    return clone(saved);
  }

  @override
  Future<Produk> addProductStock(Produk p, int quantity) async {
    final saved = rows.firstWhere((r) => r.id == p.id);
    saved.stok += quantity;
    return clone(saved);
  }

  @override
  Future<void> deleteProduct(Produk p) async {
    rows.removeWhere((r) => r.id == p.id);
  }
}

class FakeTransactions implements TransactionService {
  final FakeProducts products;
  final List<Transaksi> rows = [];
  final List<String> requestIds = [];
  bool failNext = false;
  Completer<void>? pending;
  FakeTransactions(this.products);

  @override
  Future<Transaksi> checkout({
    required String requestId,
    required Map<Produk, int> items,
    required int cash,
    required int expectedTotal,
  }) async {
    requestIds.add(requestId);
    if (pending != null) await pending!.future;
    if (failNext) {
      failNext = false;
      throw const ApiException('Stok berubah. Coba lagi.');
    }
    final previous = rows.where((r) => r.id == requestId).firstOrNull;
    if (previous != null) return previous;
    final details = <ItemTransaksi>[];
    for (final entry in items.entries) {
      final p = products.rows.firstWhere((p) => p.id == entry.key.id);
      details.add(
        ItemTransaksi(
          produkId: p.id,
          namaProduk: p.nama,
          hargaModal: p.hargaModal,
          hargaJual: p.hargaJual,
          jumlah: entry.value,
          subtotal: p.hargaJual * entry.value,
          laba: (p.hargaJual - p.hargaModal) * entry.value,
        ),
      );
      p.stok -= entry.value;
    }
    final result = Transaksi(
      id: requestId,
      nomorNota: 'WK-0000000001',
      tanggal: DateTime.now(),
      kasir: 'Dina',
      items: details,
      totalHarga: expectedTotal,
      totalLaba: details.fold(0, (sum, i) => sum + i.laba),
      bayar: cash,
      kembalian: cash - expectedTotal,
    );
    rows.insert(0, result);
    return result;
  }

  @override
  Future<List<Transaksi>> getTransactions({
    String search = '',
    DateTime? from,
    DateTime? until,
    int offset = 0,
  }) async => rows
      .where(
        (r) =>
            '${r.nomorNota} ${r.kasir}'.toLowerCase().contains(
              search.toLowerCase(),
            ) &&
            (from == null || !r.tanggal.isBefore(from)) &&
            (until == null || r.tanggal.isBefore(until)),
      )
      .skip(offset)
      .take(50)
      .toList();
  @override
  Future<Transaksi> getTransaction(String id) async =>
      rows.firstWhere((r) => r.id == id);
  @override
  Future<Laporan> getReport({DateTime? from, DateTime? until}) async {
    final list = await getTransactions(from: from, until: until);
    return Laporan(
      jumlahTransaksi: list.length,
      jumlahBarang: list.fold(
        0,
        (sum, r) => sum + r.items.fold(0, (n, i) => n + i.jumlah),
      ),
      penjualan: list.fold(0, (sum, r) => sum + r.totalHarga),
      laba: list.fold(0, (sum, r) => sum + r.totalLaba),
    );
  }
}

class FakeDocuments implements DocumentService {
  int printed = 0;
  int shared = 0;
  @override
  Future<Uint8List> priceList(
    List<Produk> products, {
    String storeName = 'Waroeng.Ku',
  }) async => Uint8List.fromList([37, 80, 68, 70]);
  @override
  Future<Uint8List> receipt(Transaksi transaction) async =>
      Uint8List.fromList([37, 80, 68, 70]);
  @override
  Future<void> printPdf(Uint8List bytes, String name) async {
    printed++;
  }

  @override
  Future<void> sharePdf(Uint8List bytes, String name) async {
    shared++;
  }
}
