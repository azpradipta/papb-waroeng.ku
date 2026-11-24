import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/main.dart';
import 'package:waroeng_ku/screens/account_deletion_screen.dart';
import 'package:waroeng_ku/services/auth_service.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuth auth;

  setUp(() => auth = FakeAuth());
  tearDown(() async => auth.events.close());

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester, {String role = 'owner'}) async {
    await auth.signIn('$role@example.com', 'valid123');
    final products = FakeProducts();
    await tester.pumpWidget(
      MyApp(
        auth: auth,
        products: products,
        transactions: FakeTransactions(products),
        documents: FakeDocuments(),
        shop: FakeShop(auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    await tap(tester, 'Hapus Akun dan Data');
  }

  testWidgets('permintaan membutuhkan persetujuan dan konfirmasi akhir', (
    tester,
  ) async {
    await start(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.textContaining('data toko Warung Uji'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deletion-consent')));
    await tester.pumpAndSettle();
    await tap(tester, 'Kirim Permintaan Hapus Akun');
    await tap(tester, 'Batal');
    expect(auth.deletionCalls, 0);
    await tap(tester, 'Kirim Permintaan Hapus Akun');
    await tap(tester, 'Ya, Kirim Permintaan');
    expect(auth.deletionCalls, 1);
    expect(
      find.text('Permintaan diterima dan menunggu diproses.'),
      findsOneWidget,
    );
    expect(auth.profile, isNotNull);
    expect(find.text('Kirim Permintaan Hapus Akun'), findsNothing);
  });

  testWidgets('kegagalan permintaan bisa dicoba ulang tanpa menghapus akun', (
    tester,
  ) async {
    await start(tester, role: 'cashier');
    expect(find.textContaining('Anda sebagai Kasir'), findsOneWidget);
    expect(find.textContaining('data toko Warung Uji'), findsNothing);
    await tester.tap(find.byKey(const Key('deletion-consent')));
    await tester.pumpAndSettle();
    auth.failDeletion = true;
    await tap(tester, 'Kirim Permintaan Hapus Akun');
    await tap(tester, 'Ya, Kirim Permintaan');
    expect(find.text('Koneksi terputus. Coba lagi.'), findsOneWidget);
    expect(auth.deletionRequest, isNull);
    expect(auth.profile!.role, 'Kasir');
    auth.failDeletion = false;
    await tap(tester, 'Kirim Permintaan Hapus Akun');
    await tap(tester, 'Ya, Kirim Permintaan');
    expect(auth.deletionCalls, 2);
    expect(find.textContaining('Nomor permintaan:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permintaan tertunda memblokir pengiriman ulang dan kembali', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('deletion-consent')));
    await tester.pumpAndSettle();
    auth.deletionPending = Completer<void>();
    await tap(tester, 'Kirim Permintaan Hapus Akun');
    await tester.tap(find.text('Ya, Kirim Permintaan'));
    await tester.pumpAndSettle();
    expect(find.text('Mengirim...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect(auth.deletionCalls, 1);
    auth.deletionPending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Nomor permintaan:'), findsOneWidget);
  });

  testWidgets('permintaan yang sudah tercatat dimuat tanpa mengirim ulang', (
    tester,
  ) async {
    auth.deletionRequest = AccountDeletionRequest(
      id: 'saved-request',
      status: 'pending',
      requestedAt: DateTime.utc(2026, 11, 20),
    );
    await start(tester);
    expect(find.text('Nomor permintaan: saved-request'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    auth.deletionRequest = AccountDeletionRequest(
      id: 'saved-request',
      status: 'processing',
      requestedAt: DateTime.utc(2026, 11, 20),
    );
    await tap(tester, 'Perbarui Status');
    expect(find.text('Penghapusan sedang diproses.'), findsOneWidget);
    expect(auth.deletionCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kebijakan privasi dapat dibaca sebelum pengguna login', (
    tester,
  ) async {
    final products = FakeProducts();
    await tester.pumpWidget(
      MyApp(
        auth: auth,
        products: products,
        transactions: FakeTransactions(products),
        documents: FakeDocuments(),
        shop: FakeShop(auth),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Kebijakan Privasi');
    expect(find.text('Privasi di Waroeng.Ku'), findsOneWidget);
    expect(auth.profile, isNull);
    await tester.scrollUntilVisible(
      find.text('Kontak pengelola'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('11231013@student.itk.ac.id'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
