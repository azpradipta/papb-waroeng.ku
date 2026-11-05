// Produk disimpan permanen di Supabase. List di bawah menjadi cache agar
// halaman-halaman lama tetap dapat berbagi data produk yang sama.
// Transaksi masih disimpan di memori dan hilang saat aplikasi ditutup.

class Produk {
  int? id;
  String nama;
  int hargaModal;
  int hargaJual;
  int stok;
  String satuan;
  DateTime? dibuatPada;

  Produk({
    this.id,
    required this.nama,
    required this.hargaModal,
    required this.hargaJual,
    required this.stok,
    required this.satuan,
    this.dibuatPada,
  });

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: _angkaDariMap(map['id'], 'id'),
      nama: map['name'] as String,
      hargaModal: _angkaDariMap(map['cost_price'], 'cost_price')!,
      hargaJual: _angkaDariMap(map['selling_price'], 'selling_price')!,
      stok: _angkaDariMap(map['stock'], 'stock')!,
      satuan: map['unit'] as String,
      dibuatPada: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': nama,
      'cost_price': hargaModal,
      'selling_price': hargaJual,
      'stock': stok,
      'unit': satuan,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': nama,
      'cost_price': hargaModal,
      'selling_price': hargaJual,
      'stock': stok,
      'unit': satuan,
    };
  }

  void salinDari(Produk produk) {
    id = produk.id;
    nama = produk.nama;
    hargaModal = produk.hargaModal;
    hargaJual = produk.hargaJual;
    stok = produk.stok;
    satuan = produk.satuan;
    dibuatPada = produk.dibuatPada;
  }

  static int? _angkaDariMap(Object? nilai, String namaKolom) {
    if (nilai == null) {
      return null;
    }
    if (nilai is int) {
      return nilai;
    }
    if (nilai is num) {
      return nilai.toInt();
    }
    return int.tryParse(nilai.toString()) ??
        (throw FormatException('Kolom $namaKolom bukan angka.'));
  }
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
