# Aset dan lisensi Waroeng.Ku

Catatan audit untuk build release, 20 November 2026.

## Logo aplikasi

`assets/icon/icon.png` adalah logo Waroeng.Ku yang digunakan pada halaman login,
ikon launcher Android, dan splash screen. Pemilik project menyatakan bahwa logo
dibuat sendiri pada percakapan 20 November 2026. Riwayat Git mencatat penambahan
aset pada commit `96857a5`, 13 September 2026; riwayat commit tidak dengan
sendirinya membuktikan kepemilikan desain. Simpan berkas desain asli sebagai
bukti proses pembuatan.

Tidak ditemukan foto produk, gambar dari internet, atau layanan gambar eksternal
di kode aplikasi. Ikon tombol dan navigasi berasal dari Material Icons bawaan
Flutter. Aplikasi tidak menambahkan berkas font khusus. PDF nota dan daftar harga
dibuat dari teks serta tabel, tanpa mengunduh gambar atau font dari internet.

## Font dan perangkat lunak pihak ketiga

| Komponen | Sumber dan lisensi |
| --- | --- |
| Material Icons | Distribusi SDK Flutter 3.32.1 lokal menyertakan `materialicons_license.txt`, berisi Creative Commons Attribution 4.0 International. Notice ini dipertahankan sesuai berkas SDK yang digunakan. Repositori Google saat ini mencantumkan Apache 2.0. |
| Roboto bawaan SDK | Notice `roboto_license.txt` dari SDK Flutter yang digunakan: Apache License 2.0. |
| Paket `pdf` dan `printing` | Berkas LICENSE pada versi paket terpasang menggunakan Apache License 2.0. |
| Flutter dan paket lainnya | Teks lisensi dikumpulkan oleh Flutter dari berkas LICENSE/NOTICES dependensi saat build. |

Notice font disalin utuh dari SDK ke
[`licenses/FONT_NOTICES.txt`](licenses/FONT_NOTICES.txt), dengan penanda nama
komponen agar tampil pada halaman lisensi Flutter. Berkas didaftarkan pada
`flutter.licenses` di `pubspec.yaml` sehingga ikut dibundel saat build.

Untuk melihat teks lisensi dari aplikasi, buka **Pengaturan → Lisensi Open
Source**. Menu tersedia untuk pemilik maupun kasir. Halaman ini menampilkan
notice yang terdaftar melalui LicenseRegistry Flutter; halaman tersebut tidak
menetapkan lisensi atau kepemilikan logo aplikasi.

Rujukan primer:

- [Material Icons oleh Google](https://github.com/google/material-design-icons/blob/master/LICENSE).
- [Lisensi Roboto generasi yang disertakan SDK](https://github.com/googlefonts/roboto-2/blob/main/LICENSE).
- [Halaman lisensi bawaan Flutter](https://api.flutter.dev/flutter/material/showLicensePage.html).

## Kesesuaian visual dengan umur

Tampilan yang diperiksa berisi logo toko, ikon navigasi, formulir akun, produk,
stok, transaksi, dan laporan. Tidak ditemukan gambar kekerasan, ketelanjangan,
perjudian, atau konten dewasa pada aset yang dibundel. Secara visual, aset
aplikasi kasir ini cocok untuk penggunaan umum.

Penilaian visual tersebut bukan rating umur resmi IARC atau Google Play.
Jika nanti aplikasi dipublikasikan, jawab kuesioner rating berdasarkan fitur dan
konten versi yang benar-benar akan diterbitkan.
