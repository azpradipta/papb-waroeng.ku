import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:waroeng_ku/data.dart';
import 'package:waroeng_ku/services/document_service.dart';

void main() {
  test(
    'daftar harga besar menghasilkan PDF multi-halaman yang dapat dicetak',
    () async {
      final products = List.generate(
        150,
        (i) => Produk(
          id: i + 1,
          nama: 'Barang $i',
          hargaModal: 1000,
          hargaJual: 2000,
          stok: 2,
          satuan: 'pcs',
        ),
      );
      final bytes = await PdfDocumentService().priceList(products);
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      final text = latin1.decode(bytes);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(text).length,
        greaterThan(1),
      );
    },
  );

  test('nota setelah produk dihapus masih dapat diekspor', () async {
    final transaction = Transaksi(
      id: 'r',
      nomorNota: 'WK-0001',
      tanggal: DateTime(2026, 11, 17),
      kasir: 'Dina',
      items: [
        ItemTransaksi(
          namaProduk: 'Produk lama',
          hargaModal: 1000,
          hargaJual: 2000,
          jumlah: 2,
          subtotal: 4000,
          laba: 2000,
        ),
      ],
      totalHarga: 4000,
      totalLaba: 2000,
      bayar: 5000,
      kembalian: 1000,
    );
    final bytes = await PdfDocumentService().receipt(transaction);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(500));
  });

  test(
    'awal periode memakai kalender lokal dan format uang menangani laba negatif',
    () {
      expect(
        awalPeriode('7 hari terakhir', DateTime(2026, 11, 17, 9)),
        DateTime(2026, 11, 11),
      );
      expect(
        awalPeriode('Bulan ini', DateTime(2026, 11, 17, 9)),
        DateTime(2026, 11, 1),
      );
      expect(awalPeriode('Semua'), isNull);
      expect(rupiah(-2500), '-Rp 2.500');
    },
  );
}
