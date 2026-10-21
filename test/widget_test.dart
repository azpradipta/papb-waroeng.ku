import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/data.dart';
import 'package:waroeng_ku/main.dart';
import 'package:waroeng_ku/screens/daftar_harga_screen.dart';
import 'package:waroeng_ku/screens/detail_produk_screen.dart';
import 'package:waroeng_ku/screens/detail_transaksi_screen.dart';
import 'package:waroeng_ku/screens/form_produk_screen.dart';
import 'package:waroeng_ku/screens/kasir_screen.dart';
import 'package:waroeng_ku/screens/laporan_screen.dart';
import 'package:waroeng_ku/screens/login_screen.dart';
import 'package:waroeng_ku/screens/main_screen.dart';
import 'package:waroeng_ku/screens/pembayaran_screen.dart';
import 'package:waroeng_ku/screens/produk_screen.dart';
import 'package:waroeng_ku/screens/riwayat_screen.dart';
import 'package:waroeng_ku/screens/tambah_stok_screen.dart';

Future<void> login(WidgetTester tester, String email, String password) async {
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.text('Masuk'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> isi(WidgetTester tester, String label, String nilai) async {
  await tester.enterText(find.widgetWithText(TextField, label), nilai);
  await tester.pump();
}

// SnackBar tampil 4 detik, ditunggu dulu supaya tidak menutupi tombol lain.
Future<void> tungguSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

Future<void> kembali(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

bool canGoBack(WidgetTester tester) {
  NavigatorState navigator = tester.state(find.byType(Navigator).first);
  return navigator.canPop();
}

void main() {
  setUp(() {
    daftarProduk.clear();
    daftarTransaksi.clear();
  });

  testWidgets('Login gagal kalau email atau password salah', (tester) async {
    await login(tester, 'pemilik@waroengku.com', 'salah');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email atau password salah'), findsOneWidget);
  });

  testWidgets('Pemilik bisa menjalankan semua use case', (tester) async {
    await login(tester, 'pemilik@waroengku.com', 'pemilik123');
    // Halaman pertama setelah login adalah Kasir.
    expect(find.byType(KasirScreen), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    // Setelah login, tombol back tidak kembali ke halaman login.
    expect(canGoBack(tester), isFalse);

    // Awalnya belum ada data sama sekali.
    await tap(tester, 'Produk');
    expect(find.text('Belum ada produk.'), findsOneWidget);

    // Menambah produk.
    await tap(tester, 'Tambah Produk');
    await tap(tester, 'Simpan');
    expect(find.text('Semua data harus diisi dengan benar'), findsOneWidget);
    await tungguSnackBar(tester);
    await isi(tester, 'Nama Produk', 'Indomie Goreng');
    await isi(tester, 'Harga Modal', '2500');
    await isi(tester, 'Harga Jual', '3500');
    await isi(tester, 'Stok', '10');
    await isi(tester, 'Satuan', 'pcs');
    await tap(tester, 'Simpan');
    expect(find.text('Indomie Goreng'), findsOneWidget);
    expect(find.text('Stok: 10 pcs'), findsOneWidget);

    // Mengedit produk.
    await tap(tester, 'Indomie Goreng');
    expect(find.byType(DetailProdukScreen), findsOneWidget);
    await tap(tester, 'Edit Produk');
    await isi(tester, 'Harga Jual', '4000');
    await tap(tester, 'Simpan');
    expect(find.text('Rp 4.000'), findsOneWidget);

    // Menambah stok.
    await tap(tester, 'Tambah Stok');
    await isi(tester, 'Jumlah Stok Masuk', '5');
    await tap(tester, 'Simpan');
    expect(find.text('15 pcs'), findsOneWidget);
    await kembali(tester);
    expect(find.text('Stok: 15 pcs'), findsOneWidget);

    // Mencetak daftar harga.
    await tap(tester, 'Daftar Harga');
    expect(find.text('Indomie Goreng (pcs)'), findsOneWidget);
    expect(find.text('Rp 4.000'), findsOneWidget);
    await tap(tester, 'Cetak Daftar Harga');
    expect(find.text('Daftar harga siap dicetak'), findsOneWidget);
    await tungguSnackBar(tester);
    await kembali(tester);

    // Memproses transaksi.
    await tap(tester, 'Kasir');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
    expect(find.text('Total: Rp 8.000'), findsOneWidget);
    await tap(tester, 'Bayar');
    await isi(tester, 'Uang Diterima', '5000');
    await tap(tester, 'Proses Pembayaran');
    expect(find.text('Uang yang diterima kurang'), findsOneWidget);
    await tungguSnackBar(tester);
    await isi(tester, 'Uang Diterima', '10000');
    expect(find.text('Rp 2.000'), findsOneWidget);
    await tap(tester, 'Proses Pembayaran');
    expect(find.text('Pembayaran Berhasil'), findsOneWidget);
    await tap(tester, 'Selesai');
    expect(find.text('Total: Rp 0'), findsOneWidget);
    expect(find.text('Stok: 13 pcs'), findsOneWidget);

    // Melihat riwayat transaksi.
    await tap(tester, 'Riwayat');
    await tap(tester, 'TRX-001');
    expect(find.byType(DetailTransaksiScreen), findsOneWidget);
    expect(find.text('Rp 10.000'), findsOneWidget);
    expect(find.text('Rp 2.000'), findsOneWidget);
    await kembali(tester);

    // Melihat laporan: penjualan 8.000, modal 5.000, laba 3.000.
    await tap(tester, 'Laporan');
    expect(find.text('Rp 8.000'), findsOneWidget);
    expect(find.text('Rp 5.000'), findsOneWidget);
    expect(find.text('Rp 3.000'), findsOneWidget);

    // Menghapus produk.
    await tap(tester, 'Produk');
    await tap(tester, 'Indomie Goreng');
    await tap(tester, 'Hapus Produk');
    await tap(tester, 'Batal');
    expect(find.byType(DetailProdukScreen), findsOneWidget);
    await tap(tester, 'Hapus Produk');
    await tap(tester, 'Hapus');
    expect(find.text('Belum ada produk.'), findsOneWidget);

    // Riwayat tetap ada walaupun produknya sudah dihapus.
    await tap(tester, 'Riwayat');
    expect(find.text('TRX-001'), findsOneWidget);

    await tap(tester, 'Kasir');
    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    // Setelah keluar, tombol back tidak kembali ke halaman sebelumnya.
    expect(canGoBack(tester), isFalse);
  });

  testWidgets('Kasir tidak melihat menu dan tombol Pemilik', (tester) async {
    daftarProduk.add(
      Produk(
        nama: 'Teh Botol',
        hargaModal: 3000,
        hargaJual: 4000,
        stok: 1,
        satuan: 'botol',
      ),
    );
    await login(tester, 'kasir@waroengku.com', 'kasir123');
    expect(find.byType(KasirScreen), findsOneWidget);
    expect(find.text('Laporan'), findsNothing);

    await tap(tester, 'Produk');
    expect(find.text('Tambah Produk'), findsNothing);
    await tap(tester, 'Teh Botol');
    expect(find.text('Harga Modal'), findsNothing);
    expect(find.text('Edit Produk'), findsNothing);
    expect(find.text('Tambah Stok'), findsNothing);
    expect(find.text('Hapus Produk'), findsNothing);
    await kembali(tester);

    // Tidak bisa menjual melebihi stok.
    await tap(tester, 'Kasir');
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
    expect(find.text('Stok Teh Botol tidak cukup'), findsOneWidget);
  });

  testWidgets('Semua screen tidak terpotong di portrait dan landscape', (
    tester,
  ) async {
    Produk produk = Produk(
      nama: 'Kopi Kapal Api Special Mix Sachet Isi Sepuluh Renceng Besar',
      hargaModal: 125000,
      hargaJual: 1500000,
      stok: 1000,
      satuan: 'renceng',
    );
    daftarProduk.add(produk);
    Transaksi transaksi = Transaksi(
      nomorNota: 'TRX-001',
      tanggal: DateTime(2026, 10, 22, 9, 5),
      kasir: 'Pemilik',
      items: [
        ItemTransaksi(
          namaProduk: produk.nama,
          hargaModal: produk.hargaModal,
          hargaJual: produk.hargaJual,
          jumlah: 2,
          subtotal: 3000000,
          laba: 2750000,
        ),
      ],
      totalHarga: 3000000,
      totalLaba: 2750000,
      bayar: 5000000,
      kembalian: 2000000,
    );
    daftarTransaksi.add(transaksi);

    List<Widget> screens = [
      const LoginScreen(),
      const MainScreen(role: 'Pemilik'),
      const KasirScreen(role: 'Pemilik'),
      PembayaranScreen(
        keranjang: {produk: 2},
        total: 3000000,
        kasir: 'Pemilik',
      ),
      const ProdukScreen(role: 'Pemilik'),
      DetailProdukScreen(role: 'Pemilik', produk: produk),
      const FormProdukScreen(),
      FormProdukScreen(produk: produk),
      TambahStokScreen(produk: produk),
      const DaftarHargaScreen(),
      const RiwayatScreen(),
      DetailTransaksiScreen(transaksi: transaksi),
      const LaporanScreen(),
    ];
    for (Size size in [const Size(320, 640), const Size(640, 320)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (Widget screen in screens) {
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$screen $size');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
