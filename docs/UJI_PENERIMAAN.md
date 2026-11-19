# Uji penerimaan pada backend aktif

Jalankan setelah kedua migrasi, Auth tanpa Confirm Email, dan fungsi manage-cashier disiapkan sesuai SETUP_SUPABASE.md. Gunakan produk/akun uji tersendiri. Pengujian ini membuat akun dan transaksi nyata pada database tujuan.

## Daftar, toko, dan Kasir

- Daftar Pemilik dari aplikasi: langsung masuk tanpa email verifikasi, nama toko tampil, tidak dapat memilih role/toko lama.
- Daftar email yang sama atau password kurang dari 8 karakter: ditolak tanpa menimpa akun.
- Ganti nama/alamat/telepon toko: muat ulang tetap tersimpan; nama toko dipakai PDF.
- Pemilik membuat Kasir: sesi tetap milik Pemilik; Kasir dapat login dengan password awal.
- Edit nama, reset password, nonaktifkan, dan aktifkan lagi Kasir: hasil tersimpan.
- Kasir yang sudah login dinonaktifkan: operasi database berikutnya ditolak, nota lama tetap terbaca Pemilik.
- Pemilik dan Kasir mengganti password sendiri lalu mencoba login dengan password baru.
- Daftar Pemilik kedua: katalog, nota, laporan, dan daftar Kasir masing-masing toko terpisah.
- Coba ID produk, nota, dan Kasir toko lain melalui RPC/fungsi: ditolak tanpa membocorkan data atau mengubah stok/password.
- Token tidak ada/tidak valid dan token Kasir tidak dapat membuat atau mereset akun melalui manage-cashier.

## Login dan akses

- Masuk dengan password salah: ditolak.
- Masuk sebagai Pemilik: menu Laporan dan pengelolaan produk tersedia.
- Tutup/buka aplikasi: sesi dipulihkan.
- Keluar lalu masuk sebagai Kasir: menu pengelolaan dan Laporan tidak tersedia; keranjang lama kosong.
- Sebagai Kasir, panggil get_report/create_product melalui klien API menggunakan token Kasir: ditolak.
- Tanpa token pengguna, panggil get_products dan baca products langsung: ditolak.

## Produk dan stok

- Pemilik menambah produk, mengedit nama/harga/satuan, lalu menambah stok.
- Muat ulang aplikasi: nilai tetap sama.
- Isi nama kosong, angka negatif, atau nominal terlalu besar: ditolak tanpa perubahan.
- Dari dua perangkat, tambah stok bersamaan: jumlah akhir sesuai total kedua penambahan.
- Edit metadata ketika perangkat lain menjual barang: stok tidak kembali ke nilai sebelum penjualan.

## Penjualan

- Pilih beberapa barang dan pindah tab: keranjang tetap ada selama sesi.
- Bayar kurang: ditolak.
- Bayar cukup: satu nota, rincian, dan perubahan stok tersimpan.
- Buka ulang aplikasi: riwayat/nota tetap ada.
- Putus koneksi setelah mengirim pembayaran, lalu retry pada layar yang sama: ID nota tetap sama dan stok berkurang satu kali.
- Ubah harga atau habiskan stok lewat perangkat lain sebelum bayar: pembayaran ditolak seluruhnya.
- Uji satu stok terakhir dengan dua perangkat/koneksi bersamaan: hanya satu pembayaran berhasil, stok akhir nol.
- Hapus produk yang sudah terjual: nota lama tetap menampilkan nama dan harga saat transaksi.

## Riwayat dan laporan

- Cari nomor nota dan nama petugas.
- Buat lebih dari 50 nota uji; tombol Muat Lebih Banyak membuka halaman berikutnya.
- Pilih hari ini, tujuh hari, bulan ini, dan rentang tanggal.
- Cocokkan penjualan, modal, laba, jumlah nota, serta jumlah barang dengan data SQL.
- Kasir tidak menerima harga modal atau laba dalam respons katalog/nota.

## Cetak dan perangkat

- Cetak daftar harga dan nota melalui layanan cetak Android yang kompatibel.
- Simpan/bagikan PDF dan buka berkas yang dihasilkan.
- Uji daftar harga dengan banyak halaman.
- Uji tombol kembali, keyboard terbuka, layar 320 piksel, dan jaringan putus.
- Uji APK pada perangkat Android target; iOS/macOS membutuhkan build dan verifikasi pada macOS.
