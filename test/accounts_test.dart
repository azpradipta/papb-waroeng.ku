import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/main.dart';
import 'package:waroeng_ku/screens/main_screen.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeShop shop;
  late FakeProducts products;
  setUp(() {
    auth = FakeAuth();
    shop = FakeShop(auth);
    products = FakeProducts();
  });
  tearDown(() async => auth.events.close());
  Future<void> start(WidgetTester tester, {String? role}) async {
    if (role != null) await auth.signIn('$role@example.com', 'valid123');
    await tester.pumpWidget(
      MyApp(
        auth: auth,
        products: products,
        transactions: FakeTransactions(products),
        documents: FakeDocuments(),
        shop: shop,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> settings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String text) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tap(tester, text);
  }

  testWidgets(
    'daftar memvalidasi password lalu langsung membuka toko sebagai Pemilik',
    (tester) async {
      await start(tester);
      await tap(tester, 'Belum punya toko? Daftar Pemilik');
      for (final entry in [
        'Rani',
        'Warung Rani',
        'rani@example.com',
        'password123',
        'berbeda123',
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      await tap(tester, 'Daftar dan Buka Toko');
      expect(find.text('Password tidak sama.'), findsOneWidget);
      expect(auth.profile, isNull);
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');
      await tap(tester, 'Daftar dan Buka Toko');
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Warung Rani'), findsOneWidget);
      expect(auth.profile!.role, 'Pemilik');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pemilik membuat, mengedit, mereset password, dan menonaktifkan Kasir tanpa berganti sesi',
    (tester) async {
      await start(tester, role: 'owner');
      await settings(tester);
      await tap(tester, 'Kelola Kasir');
      await tap(tester, 'Tambah Kasir');
      for (final entry in [
        'Dina',
        'dina@example.com',
        'password123',
        'password123',
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      await tap(tester, 'Simpan Kasir');
      expect(shop.rows.single.nama, 'Dina');
      expect(auth.profile!.role, 'Pemilik');
      expect(auth.profile!.id, 'owner@example.com');
      await menu(tester, 'Edit Kasir');
      await tester.enterText(find.byType(TextFormField).first, 'Dina Baru');
      await tap(tester, 'Simpan Kasir');
      expect(shop.rows.single.nama, 'Dina Baru');
      await menu(tester, 'Reset Password');
      for (final field
          in find.byType(TextFormField).evaluate().toList().asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(field.key),
          'passwordBaru',
        );
      }
      await tap(tester, 'Simpan Password');
      expect(shop.resetId, shop.rows.single.id);
      expect(shop.resetPassword, 'passwordBaru');
      expect(auth.changedPassword, isNull);
      await menu(tester, 'Nonaktifkan');
      await tap(tester, 'Ya, Lanjutkan');
      expect(shop.rows.single.aktif, isFalse);
      expect(find.textContaining('Nonaktif'), findsOneWidget);
      await menu(tester, 'Aktifkan');
      await tap(tester, 'Ya, Lanjutkan');
      expect(shop.rows.single.aktif, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'perubahan nama toko terlihat di halaman utama dan keranjang tetap ada',
    (tester) async {
      await start(tester, role: 'owner');
      await tester.tap(find.byTooltip('Tambah Beras 1 kg'));
      await tester.pumpAndSettle();
      await settings(tester);
      await tap(tester, 'Profil Toko');
      await tester.enterText(find.byType(TextFormField).first, 'Toko Baru');
      await tap(tester, 'Simpan Toko');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Toko Baru'), findsOneWidget);
      expect(find.text('Total: Rp 15.000'), findsOneWidget);
      expect(shop.store.nama, 'Toko Baru');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Kasir hanya memperoleh pengaturan password dan dapat mengganti password sendiri',
    (tester) async {
      await start(tester, role: 'cashier');
      await settings(tester);
      expect(find.text('Kelola Kasir'), findsNothing);
      expect(find.text('Profil Toko'), findsNothing);
      await tap(tester, 'Ganti Password');
      await tester.enterText(find.byType(TextFormField).first, 'passwordBaru');
      await tester.enterText(find.byType(TextFormField).last, 'passwordBaru');
      await tap(tester, 'Simpan Password');
      expect(auth.changedPassword, 'passwordBaru');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form daftar tetap bisa digunakan pada layar 320 piksel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester);
    await tap(tester, 'Belum punya toko? Daftar Pemilik');
    await tap(tester, 'Daftar dan Buka Toko');
    expect(auth.profile, isNull);
    expect(tester.takeException(), isNull);
  });
}
