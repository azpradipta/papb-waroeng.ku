# Waroeng.Ku

Aplikasi kasir dan pengelolaan warung untuk Pemilik dan Kasir. Project mata kuliah PAPB.

Progress UTS: tampilan (frontend) dan perpindahan halaman. Belum terhubung ke database, jadi data produk dan transaksi hanya disimpan di `List` (memori) dan hilang saat aplikasi ditutup. Saat pertama dibuka, belum ada data apa pun.

## Menjalankan

```
flutter pub get
flutter run
```

## Akun

| Peran | Email | Password |
| --- | --- | --- |
| Pemilik | `pemilik@waroengku.com` | `pemilik123` |
| Kasir | `kasir@waroengku.com` | `kasir123` |

## Use Case dan Halaman

| Use case | Halaman | Kasir | Pemilik |
| --- | --- | :---: | :---: |
| Autentikasi | Login, tombol keluar di halaman Kasir | Ya | Ya |
| Mencetak daftar harga | Produk > Daftar Harga | Ya | Ya |
| Memproses transaksi | Kasir > Pembayaran | Ya | Ya |
| Melihat stok produk | Produk, Detail Produk | Ya | Ya |
| Melihat riwayat transaksi | Riwayat > Detail Transaksi | Ya | Ya |
| Menambah produk | Produk > Tambah Produk | Tidak | Ya |
| Mengedit produk | Detail Produk > Edit Produk | Tidak | Ya |
| Menghapus produk | Detail Produk > Hapus Produk | Tidak | Ya |
| Menambah stok produk | Detail Produk > Tambah Stok | Tidak | Ya |
| Melihat laporan keuangan | Laporan | Tidak | Ya |

## Struktur

```
lib/
├── main.dart
├── data.dart                   # Class Produk, Transaksi, dan List penyimpan data
└── screens/                    # Satu file untuk setiap halaman
```
