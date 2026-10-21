// Data hanya disimpan di List (memori HP), belum ke database.
// Karena itu semua data hilang saat aplikasi ditutup.

class Produk {
  String nama;
  int hargaModal;
  int hargaJual;
  int stok;
  String satuan;

  Produk({
    required this.nama,
    required this.hargaModal,
    required this.hargaJual,
    required this.stok,
    required this.satuan,
  });
}

// Nama dan harga disalin saat transaksi, supaya riwayat tidak berubah
// walaupun produknya nanti diedit atau dihapus.
class ItemTransaksi {
  String namaProduk;
  int hargaModal;
  int hargaJual;
  int jumlah;
  int subtotal;
  int laba;

  ItemTransaksi({
    required this.namaProduk,
    required this.hargaModal,
    required this.hargaJual,
    required this.jumlah,
    required this.subtotal,
    required this.laba,
  });
}

class Transaksi {
  String nomorNota;
  DateTime tanggal;
  String kasir;
  List<ItemTransaksi> items;
  int totalHarga;
  int totalLaba;
  int bayar;
  int kembalian;

  Transaksi({
    required this.nomorNota,
    required this.tanggal,
    required this.kasir,
    required this.items,
    required this.totalHarga,
    required this.totalLaba,
    required this.bayar,
    required this.kembalian,
  });
}

List<Produk> daftarProduk = [];
List<Transaksi> daftarTransaksi = [];

// Contoh: 15000 menjadi "Rp 15.000".
String rupiah(int angka) {
  String teks = angka.abs().toString();
  String hasil = '';
  for (int i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) {
      hasil += '.';
    }
    hasil += teks[i];
  }
  if (angka < 0) {
    return '-Rp $hasil';
  }
  return 'Rp $hasil';
}

// Contoh: "22/10/2026 09:05".
String formatTanggal(DateTime waktu) {
  String hari = waktu.day.toString().padLeft(2, '0');
  String bulan = waktu.month.toString().padLeft(2, '0');
  String jam = waktu.hour.toString().padLeft(2, '0');
  String menit = waktu.minute.toString().padLeft(2, '0');
  return '$hari/$bulan/${waktu.year} $jam:$menit';
}
