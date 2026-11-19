import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/main.dart';
import 'package:waroeng_ku/screens/main_screen.dart';
import 'package:waroeng_ku/screens/login_screen.dart';
import 'package:waroeng_ku/screens/detail_transaksi_screen.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeProducts products;
  late FakeTransactions transactions;
  late FakeDocuments documents;
  late FakeShop shop;

  setUp(() {
    auth = FakeAuth();
    products = FakeProducts();
    transactions = FakeTransactions(products);
    documents = FakeDocuments();
    shop = FakeShop(auth);
  });
  tearDown(() async => auth.events.close());

  Future<void> start(WidgetTester tester, {String role = 'cashier'}) async {
    await tester.pumpWidget(
      MyApp(
        auth: auth,
        products: products,
        transactions: transactions,
        documents: documents,
        shop: shop,
      ),
    );
    await tester.pumpAndSettle();
    if (auth.profile == null) {
      await tester.enterText(
        find.byKey(const Key('email')),
        '$role@example.com',
      );
      await tester.enterText(find.byKey(const Key('password')), 'valid123');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
    }
    expect(find.byType(MainScreen), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Login salah, login benar, menu peran, dan logout membersihkan sesi',
    (tester) async {
      await tester.pumpWidget(
        MyApp(
          auth: auth,
          products: products,
          transactions: transactions,
          documents: documents,
          shop: shop,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email')),
        'cashier@example.com',
      );
      await tester.enterText(find.byKey(const Key('password')), 'salah');
      await tap(tester, 'Masuk');
      expect(find.text('Email atau password salah.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('password')), 'valid123');
      await tap(tester, 'Masuk');
      expect(find.text('Dina • Kasir'), findsOneWidget);
      expect(find.text('Laporan'), findsNothing);
      await tap(tester, 'Produk');
      expect(find.text('Tambah Produk'), findsNothing);
      await tester.tap(find.byTooltip('Keluar'));
      await tester.pumpAndSettle();
      await tap(tester, 'Keluar');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('Pemilik CRUD produk dan stok tersimpan melalui modul data', (
    tester,
  ) async {
    await start(tester, role: 'owner');
    await tap(tester, 'Produk');
    await tap(tester, 'Tambah Produk');
    for (final entry in [
      'Teh Uji',
      '2000',
      '4000',
      '8',
      'botol',
    ].asMap().entries) {
      await tester.enterText(
        find.byType(TextFormField).at(entry.key),
        entry.value,
      );
    }
    await tap(tester, 'Simpan');
    expect(products.rows.length, 3);
    await tap(tester, 'Teh Uji');
    await tap(tester, 'Edit Produk');
    await tester.enterText(find.byType(TextFormField).at(2), '5000');
    await tap(tester, 'Simpan');
    expect(products.rows.last.hargaJual, 5000);
    await tap(tester, 'Tambah Stok');
    await tester.enterText(find.byType(TextField), '3');
    await tap(tester, 'Simpan');
    expect(products.rows.last.stok, 11);
    await tap(tester, 'Hapus Produk');
    await tap(tester, 'Hapus');
    expect(products.rows.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Keranjang bertahan antar menu, gagal bayar aman, retry dan klik ganda tidak menggandakan nota',
    (tester) async {
      await start(tester);
      await tester.tap(find.byTooltip('Tambah Beras 1 kg'));
      await tester.pumpAndSettle();
      await tap(tester, 'Produk');
      await tap(tester, 'Kasir');
      expect(find.text('Total: Rp 15.000'), findsOneWidget);
      await tap(tester, 'Bayar');
      await tester.enterText(find.byKey(const Key('cash-paid')), '1000');
      await tap(tester, 'Proses Pembayaran');
      expect(transactions.rows, isEmpty);
      await tester.enterText(find.byKey(const Key('cash-paid')), '20000');
      transactions.failNext = true;
      await tap(tester, 'Proses Pembayaran');
      expect(find.text('Stok berubah. Coba lagi.'), findsOneWidget);
      expect(products.rows.first.stok, 10);
      transactions.pending = Completer<void>();
      await tester.tap(find.text('Proses Pembayaran'));
      await tester.tap(find.text('Proses Pembayaran'));
      await tester.pump();
      expect(transactions.requestIds.length, 2);
      expect(transactions.requestIds.first, transactions.requestIds.last);
      transactions.pending!.complete();
      await tester.pumpAndSettle();
      expect(transactions.rows.length, 1);
      expect(products.rows.first.stok, 9);
      await tap(tester, 'Selesai');
      expect(find.text('Total: Rp 0'), findsOneWidget);
      await tap(tester, 'Riwayat');
      await tap(tester, 'WK-0000000001');
      expect(find.byType(DetailTransaksiScreen), findsOneWidget);
      await tap(tester, 'Cetak Nota');
      expect(documents.printed, 1);
      await tap(tester, 'Simpan / Bagikan PDF');
      expect(documents.shared, 1);
      expect(tester.takeException(), isNull);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DetailTransaksiScreen), findsNothing);
    },
  );

  testWidgets('Tombol kembali diblokir selama penyimpanan produk berlangsung', (
    tester,
  ) async {
    await start(tester, role: 'owner');
    await tap(tester, 'Produk');
    await tap(tester, 'Tambah Produk');
    for (final entry in [
      'Produk Tunggu',
      '1000',
      '2000',
      '2',
      'pcs',
    ].asMap().entries) {
      await tester.enterText(
        find.byType(TextFormField).at(entry.key),
        entry.value,
      );
    }
    products.savePending = Completer<void>();
    await tap(tester, 'Simpan');
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Tambah Produk'), findsWidgets);
    expect(find.text('Menyimpan...'), findsOneWidget);
    products.savePending!.complete();
    await tester.pumpAndSettle();
    expect(products.rows.where((p) => p.nama == 'Produk Tunggu').length, 1);
    expect(find.text('Menyimpan...'), findsNothing);
  });

  testWidgets('Data dan sesi dimuat ulang setelah aplikasi dibuat ulang', (
    tester,
  ) async {
    await start(tester, role: 'owner');
    await transactions.checkout(
      requestId: 'saved',
      items: {products.rows.first: 2},
      cash: 50000,
      expectedTotal: 30000,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await start(tester);
    expect(find.text('Bu Sri • Pemilik'), findsOneWidget);
    await tap(tester, 'Riwayat');
    expect(find.text('WK-0000000001'), findsOneWidget);
    await tap(tester, 'Laporan');
    expect(find.text('Rp 30.000'), findsOneWidget);
    expect(find.text('Rp 6.000'), findsOneWidget);
  });

  testWidgets('Koneksi gagal bisa dicoba ulang tanpa kehilangan akses keluar', (
    tester,
  ) async {
    products.failLoad = true;
    await start(tester);
    expect(find.text('Koneksi terputus.'), findsOneWidget);
    expect(find.byTooltip('Keluar'), findsOneWidget);
    products.failLoad = false;
    await tap(tester, 'Coba Lagi');
    expect(find.text('Beras 1 kg'), findsOneWidget);
  });

  testWidgets('Halaman ponsel kecil dan cetak daftar harga dapat digunakan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester, role: 'owner');
    await tap(tester, 'Produk');
    await tap(tester, 'Daftar Harga');
    await tap(tester, 'Cetak Daftar Harga');
    await tap(tester, 'Simpan / Bagikan PDF');
    expect(documents.printed, 1);
    expect(documents.shared, 1);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tap(tester, 'Beras 1 kg');
    expect(tester.takeException(), isNull);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tap(tester, 'Riwayat');
    await tap(tester, 'Laporan');
    expect(tester.takeException(), isNull);
  });
}
