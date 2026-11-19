# Waroeng.Ku

Aplikasi kasir Flutter dengan Supabase Auth dan PostgreSQL. Pemilik mendaftar langsung dari aplikasi, membuat toko, dan mengelola akun Kasir. Login memakai email/password tanpa verifikasi email, undangan, atau Google.

## Setup

Ikuti [panduan setup Supabase](docs/SETUP_SUPABASE.md): aktifkan signup tanpa Confirm Email, jalankan dua migrasi berurutan, lalu deploy fungsi `manage-cashier`. Akun Pemilik dan Kasir tidak perlu dibuat melalui Dashboard.

Isi `.env` berdasarkan `.env.example`, lalu jalankan:

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

Konfigurasi menggunakan Project URL dan publishable key. Secret key hanya dipakai di Edge Function. Docker tidak dibutuhkan untuk menggunakan Supabase cloud.

## Fitur

| Fitur | Pemilik | Kasir |
| --- | :---: | :---: |
| Login, logout, sesi tersimpan, ganti password | Ya | Ya |
| Daftar dan membuat toko | Ya | Tidak |
| Profil toko: nama, alamat, telepon | Edit | Tidak |
| Buat/edit/nonaktifkan/aktifkan Kasir dan reset password | Ya | Tidak |
| Produk, pencarian, filter stok, daftar harga PDF | Ya | Ya |
| Pembayaran tunai, nota PDF, riwayat dan detail transaksi | Ya | Ya |
| Tambah/edit/hapus produk dan tambah stok | Ya | Tidak |
| Laporan penjualan, modal, dan laba kotor | Ya | Tidak |

Satu Pemilik memiliki satu toko; satu akun terkait satu toko. Produk, pegawai, transaksi, dan laporan diperiksa berdasarkan toko pada backend. Kasir yang dinonaktifkan kehilangan akses tanpa menghapus riwayat. Harga modal dan laba hanya dikirim kepada Pemilik.

Checkout menyimpan nota, rincian, dan stok secara atomik. Retry pada layar pembayaran yang sama memakai ID permintaan yang sama. Nama toko tampil pada halaman utama dan PDF.

## Struktur

```text
lib/
  config/       konfigurasi dari dart-define
  screens/      login, daftar, kasir, toko, pegawai, password, produk, laporan
  services/     autentikasi, toko/pegawai, produk, transaksi, dokumen
  widgets/      field akun, filter periode, tampilan gagal muat
supabase/
  migrations/   skema dasar, dilanjutkan toko dan akun
  functions/    fungsi server manage-cashier
  config.toml   konfigurasi fungsi
docs/
  diagrams/     ERD dan use case rancangan awal
  SETUP_SUPABASE.md  langkah setup dan running
  IMPLEMENTASI.md   model dan perilaku aplikasi
  UJI_PENERIMAAN.md skenario uji manual
```

[ERD](docs/diagrams/erd.png) dan [use case](docs/diagrams/usecase.png) merupakan rancangan awal project. Pemetaan fitur dan model terbaru dijelaskan di [IMPLEMENTASI.md](docs/IMPLEMENTASI.md). Langkah pengujian manual ada di [UJI_PENERIMAAN.md](docs/UJI_PENERIMAAN.md).

## Pengujian

```powershell
flutter analyze
flutter test
python tool/check_backend.py
```

Pemeriksaan backend tidak menampilkan key, tidak mendaftar akun, dan tidak membuat transaksi. Untuk tes SQL dan fungsi akun yang terisolasi:

```powershell
Push-Location tool/db_tests
npm ci
npm test
Pop-Location
```

Tes database memakai PostgreSQL WASM/PGlite dengan pengganti Auth, tidak tersambung ke data cloud. Tes handler fungsi memakai klien Auth pengganti. Deploy fungsi, konfigurasi Auth, dua koneksi transaksi sungguhan, dan printer fisik perlu diperiksa pada backend/perangkat aktif.

## Build

```powershell
flutter build web --dart-define-from-file=.env
flutter build apk --debug --dart-define-from-file=.env
```

Cetak menggunakan dialog cetak perangkat dan dapat disimpan sebagai PDF. Integrasi Bluetooth ESC/POS khusus belum disertakan. Laba kotor belum memperhitungkan biaya operasional. Pemulihan password Pemilik yang sudah keluar dan permintaan penghapusan akun/data untuk rilis publik belum disertakan.
