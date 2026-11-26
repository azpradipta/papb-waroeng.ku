import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/main.dart';
import 'package:waroeng_ku/screens/account_deletion_screen.dart';
import 'package:waroeng_ku/screens/login_screen.dart';
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

  Future<void> password(WidgetTester tester, String value) async {
    final field = find.descendant(
      of: find.byKey(const Key('deletion-password')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pumpAndSettle();
  }

  Future<void> consent(WidgetTester tester) async {
    final checkbox = find.byKey(const Key('deletion-consent'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'password, persetujuan dan konfirmasi diperlukan lalu logout aman',
    (tester) async {
      await start(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        find.textContaining('seluruh data toko Warung Uji'),
        findsOneWidget,
      );
      await consent(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await password(tester, 'valid123');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('deletion-password')),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tap(tester, 'Hapus Akun Permanen');
      await tap(tester, 'Batal');
      expect(auth.deletionCalls, 0);
      await tap(tester, 'Hapus Akun Permanen');
      await tap(tester, 'Ya, Hapus Permanen');
      expect(auth.deletionCalls, 1);
      expect(auth.deletionPassword, 'valid123');
      expect(find.text('Permintaan diterima'), findsOneWidget);
      expect(
        find.textContaining('Akun belum dinyatakan selesai dihapus.'),
        findsOneWidget,
      );
      expect(auth.profile, isNotNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(tester, 'Kembali ke Login');
      expect(auth.profile, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AccountDeletionScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password salah bisa diperbaiki tanpa logout atau permintaan baru',
    (tester) async {
      await start(tester, role: 'cashier');
      expect(find.textContaining('Anda sebagai Kasir'), findsOneWidget);
      expect(find.textContaining('seluruh data toko Warung Uji'), findsNothing);
      await password(tester, 'wrong123');
      await consent(tester);
      await tap(tester, 'Hapus Akun Permanen');
      await tap(tester, 'Ya, Hapus Permanen');
      expect(
        find.text('Password salah. Periksa dan coba lagi.'),
        findsOneWidget,
      );
      expect(auth.deletionRequest, isNull);
      expect(auth.profile!.role, 'Kasir');
      await password(tester, 'valid123');
      await tap(tester, 'Hapus Akun Permanen');
      await tap(tester, 'Ya, Hapus Permanen');
      expect(auth.deletionCalls, 2);
      await tap(tester, 'Kembali ke Login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('kegagalan jaringan mempertahankan akun dan bisa dicoba ulang', (
    tester,
  ) async {
    await start(tester);
    await password(tester, 'valid123');
    await consent(tester);
    auth.failDeletion = true;
    await tap(tester, 'Hapus Akun Permanen');
    await tap(tester, 'Ya, Hapus Permanen');
    expect(find.text('Koneksi terputus. Coba lagi.'), findsOneWidget);
    expect(auth.deletionRequest, isNull);
    expect(auth.profile, isNotNull);
    auth.failDeletion = false;
    await tap(tester, 'Hapus Akun Permanen');
    await tap(tester, 'Ya, Hapus Permanen');
    expect(find.text('Permintaan diterima'), findsOneWidget);
    await tap(tester, 'Kembali ke Login');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ketukan ganda dan kembali diblokir selama pengiriman', (
    tester,
  ) async {
    await start(tester);
    await password(tester, 'valid123');
    await consent(tester);
    auth.deletionPending = Completer<void>();
    await tap(tester, 'Hapus Akun Permanen');
    final confirm = find.text('Ya, Hapus Permanen');
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Mengirim...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect(auth.deletionCalls, 1);
    auth.deletionPending!.complete();
    await tester.pumpAndSettle();
    await tap(tester, 'Kembali ke Login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending lama bisa diotorisasi, processing tidak dikirim ulang', (
    tester,
  ) async {
    auth.deletionRequest = AccountDeletionRequest(
      id: 'saved-request',
      status: 'pending',
      requestedAt: DateTime.utc(2026, 11, 20),
    );
    await start(tester);
    expect(find.text('Nomor permintaan: saved-request'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('deletion-consent')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await password(tester, 'valid123');
    await consent(tester);
    await tap(tester, 'Hapus Akun Permanen');
    await tap(tester, 'Ya, Hapus Permanen');
    expect(auth.deletionCalls, 1);
    expect(auth.deletionRequest!.id, 'saved-request');
    await tap(tester, 'Kembali ke Login');
    auth.deletionRequest = AccountDeletionRequest(
      id: 'saved-request',
      status: 'processing',
      requestedAt: DateTime.utc(2026, 11, 20),
    );
    await start(tester);
    expect(find.text('Penghapusan sedang diproses otomatis.'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const Key('deletion-password')), findsNothing);
    await tap(tester, 'Perbarui Status');
    expect(auth.deletionCalls, 1);
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
