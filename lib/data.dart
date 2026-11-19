// Model data mengikuti ERD. Sumber data aplikasi adalah Supabase.

class Profil {
  final String id;
  final String nama;
  final String role;
  final String tokoId;
  final String namaToko;
  const Profil({
    required this.id,
    required this.nama,
    required this.role,
    required this.tokoId,
    required this.namaToko,
  });
  bool get isPemilik => role == 'Pemilik';

  factory Profil.fromMap(Map<String, dynamic> map) {
    final role = map['role'] as String;
    if (role != 'Pemilik' && role != 'Kasir') {
      throw const FormatException('Peran profil tidak valid.');
    }
    return Profil(
      id: map['id'] as String,
      nama: map['full_name'] as String,
      role: role,
      tokoId: map['store_id'] as String,
      namaToko: map['store_name'] as String,
    );
  }
}

class Toko {
  final String id;
  final String nama;
  final String alamat;
  final String telepon;
  const Toko({
    required this.id,
    required this.nama,
    this.alamat = '',
    this.telepon = '',
  });
  factory Toko.fromMap(Map<String, dynamic> map) => Toko(
    id: map['id'] as String,
    nama: map['name'] as String,
    alamat: map['address'] as String? ?? '',
    telepon: map['phone'] as String? ?? '',
  );
}

class AkunKasir {
  final String id;
  final String nama;
  final String email;
  final bool aktif;
  const AkunKasir({
    required this.id,
    required this.nama,
    required this.email,
    required this.aktif,
  });
  factory AkunKasir.fromMap(Map<String, dynamic> map) => AkunKasir(
    id: map['id'] as String,
    nama: map['full_name'] as String,
    email: map['email'] as String,
    aktif: map['is_active'] as bool,
  );
}

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
  int? produkId;
  String namaProduk;
  int hargaModal;
  int hargaJual;
  int jumlah;
  int subtotal;
  int laba;

  ItemTransaksi({
    this.produkId,
    required this.namaProduk,
    required this.hargaModal,
    required this.hargaJual,
    required this.jumlah,
    required this.subtotal,
    required this.laba,
  });

  factory ItemTransaksi.fromMap(Map<String, dynamic> map) => ItemTransaksi(
    produkId: (map['product_id'] as num?)?.toInt(),
    namaProduk: map['product_name'] as String,
    hargaModal: (map['cost_price'] as num?)?.toInt() ?? 0,
    hargaJual: (map['selling_price'] as num).toInt(),
    jumlah: (map['qty'] as num).toInt(),
    subtotal: (map['subtotal'] as num).toInt(),
    laba: (map['profit'] as num?)?.toInt() ?? 0,
  );
}

class Transaksi {
  final String id;
  String nomorNota;
  DateTime tanggal;
  String kasir;
  final String namaToko;
  List<ItemTransaksi> items;
  int totalHarga;
  int totalLaba;
  int bayar;
  int kembalian;

  Transaksi({
    required this.id,
    required this.nomorNota,
    required this.tanggal,
    required this.kasir,
    this.namaToko = 'Waroeng.Ku',
    required this.items,
    required this.totalHarga,
    required this.totalLaba,
    required this.bayar,
    required this.kembalian,
  });

  factory Transaksi.fromMap(Map<String, dynamic> map) => Transaksi(
    id: map['id'] as String,
    nomorNota: map['invoice_code'] as String,
    tanggal: DateTime.parse(map['created_at'] as String).toLocal(),
    kasir: map['cashier_name'] as String,
    namaToko: map['store_name'] as String? ?? 'Waroeng.Ku',
    items: [
      for (final item in (map['items'] as List? ?? []))
        ItemTransaksi.fromMap(Map<String, dynamic>.from(item as Map)),
    ],
    totalHarga: (map['total_price'] as num).toInt(),
    totalLaba: (map['total_profit'] as num?)?.toInt() ?? 0,
    bayar: (map['cash_paid'] as num).toInt(),
    kembalian: (map['change_paid'] as num).toInt(),
  );
}

class Laporan {
  final int jumlahTransaksi;
  final int jumlahBarang;
  final int penjualan;
  final int laba;
  const Laporan({
    required this.jumlahTransaksi,
    required this.jumlahBarang,
    required this.penjualan,
    required this.laba,
  });
  int get modal => penjualan - laba;

  factory Laporan.fromMap(Map<String, dynamic> map) => Laporan(
    jumlahTransaksi: (map['transaction_count'] as num).toInt(),
    jumlahBarang: (map['item_count'] as num).toInt(),
    penjualan: (map['total_sales'] as num).toInt(),
    laba: (map['total_profit'] as num).toInt(),
  );
}

DateTime? awalPeriode(String periode, [DateTime? waktu]) {
  final now = waktu ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (periode) {
    'Hari ini' => today,
    '7 hari terakhir' => today.subtract(const Duration(days: 6)),
    'Bulan ini' => DateTime(now.year, now.month),
    _ => null,
  };
}

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
