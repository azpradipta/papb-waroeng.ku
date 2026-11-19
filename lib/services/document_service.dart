import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data.dart';

abstract interface class DocumentService {
  Future<Uint8List> priceList(
    List<Produk> products, {
    String storeName = 'Waroeng.Ku',
  });
  Future<Uint8List> receipt(Transaksi transaction);
  Future<void> printPdf(Uint8List bytes, String name);
  Future<void> sharePdf(Uint8List bytes, String name);
}

class PdfDocumentService implements DocumentService {
  @override
  Future<Uint8List> priceList(
    List<Produk> products, {
    String storeName = 'Waroeng.Ku',
  }) async {
    final doc = pw.Document(title: 'Daftar Harga $storeName');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(text: 'Daftar Harga $storeName'),
          pw.Text('Diperbarui: ${formatTanggal(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Produk', 'Satuan', 'Harga'],
            data: [
              for (final p in products) [p.nama, p.satuan, rupiah(p.hargaJual)],
            ],
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.orange100,
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
        footer: (context) =>
            pw.Text('Halaman ${context.pageNumber} / ${context.pagesCount}'),
      ),
    );
    return doc.save();
  }

  @override
  Future<Uint8List> receipt(Transaksi transaction) async {
    final doc = pw.Document(title: transaction.nomorNota);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        build: (_) => [
          pw.Header(text: transaction.namaToko),
          pw.Text('Nota: ${transaction.nomorNota}'),
          pw.Text(formatTanggal(transaction.tanggal)),
          pw.Text('Kasir: ${transaction.kasir}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Barang', 'Jumlah', 'Subtotal'],
            data: [
              for (final i in transaction.items)
                [
                  i.namaProduk,
                  '${i.jumlah} x ${rupiah(i.hargaJual)}',
                  rupiah(i.subtotal),
                ],
            ],
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total: ${rupiah(transaction.totalHarga)}'),
          pw.Text('Tunai: ${rupiah(transaction.bayar)}'),
          pw.Text('Kembalian: ${rupiah(transaction.kembalian)}'),
          pw.SizedBox(height: 16),
          pw.Text('Terima kasih telah berbelanja.'),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Future<void> printPdf(Uint8List bytes, String name) async {
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
  }

  @override
  Future<void> sharePdf(Uint8List bytes, String name) async {
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}
