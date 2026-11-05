# Waroeng.Ku

Aplikasi kasir dan pengelolaan warung untuk Pemilik dan Kasir. Project mata kuliah PAPB.

Modul produk sudah terhubung ke tabel `products` di Supabase. Baca, tambah, edit, tambah stok, pengurangan stok saat pembayaran, dan hapus produk dikirim melalui Data API/RPC Supabase. Transaksi dan laporan masih disimpan di `List` (memori) dan hilang saat aplikasi ditutup.

## Menjalankan

Isi Project URL dan publishable key Supabase pada file `.env`:

```env
SUPABASE_URL=https://PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=KEY_KAMU
```

Kemudian jalankan:

```powershell
flutter pub get
flutter run --dart-define-from-file=.env
```

File `.env` diabaikan oleh Git dan tidak boleh diisi dengan secret key atau
`service_role`. Sebelum menjalankan aplikasi, jalankan `supabase/products.sql`
melalui Supabase SQL Editor. Penjelasan setup, daftar API, alur source code, dan
panduan demo tersedia di `DOKUMENTASI_API_PRODUK.md`.

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
