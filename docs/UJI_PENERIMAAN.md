# Checklist demo dan uji penerimaan Waroeng.Ku

Daftar ini disusun berdasarkan kode aplikasi dan backend saat ini. Seluruh skenario di bawah berstatus **belum diuji manual** sampai kamu menjalankannya dan mencatat hasil. Preflight lulus memastikan layanan tersedia; belum membuktikan seluruh alur pengguna lulus.

Gunakan akun, toko, produk, dan uang contoh. Pengujian membuat akun dan transaksi sungguhan pada project Supabase yang dituju aplikasi. Jangan memakai transaksi operasional untuk percobaan.

## Persiapan dan urutan

1. Ikuti [SETUP_SUPABASE.md](SETUP_SUPABASE.md), lalu jalankan `python tool/check_backend.py`; hasilnya harus **Preflight lulus**.
2. Jalankan `flutter run -d chrome --dart-define-from-file=.env` dari root project.
3. Siapkan tiga email berbeda yang valid: Pemilik A, Kasir A, Pemilik B. Catat password uji terbaru setelah diubah/reset.
4. Gunakan nama toko yang mudah dibedakan: **Toko Demo A** dan **Toko Demo B**. Untuk perhitungan acuan, Toko Demo A harus baru dan belum punya transaksi.
5. Gunakan Chrome biasa untuk satu sesi, Incognito/profil browser lain untuk sesi kedua. Dua tab biasa pada origin yang sama dapat berbagi sesi; jangan menganggapnya dua akun independen.
6. Kerjakan uji produk menggunakan **Produk CRUD Demo**, kemudian buat dua transaksi acuan menggunakan Mie Demo dan Air Demo. Jangan mengubah harga/modal/stok kedua produk acuan sebelum perhitungannya diperiksa.
7. Setelah laporan acuan cocok, lanjutkan perubahan harga, penghapusan produk terjual, transaksi tambahan, offline, dan dua perangkat. Uji tersebut dapat mengubah angka laporan berikutnya.
8. Kerjakan uji akun nonaktif setelah transaksi acuan tersimpan. Aktifkan kembali Kasir sebelum melanjutkan tes lain yang memerlukannya.

## Data contoh dan perhitungan acuan

Masukkan angka tanpa titik ribuan, misalnya `5000`, bukan `5.000`. Tampilan aplikasi yang akan memformat menjadi rupiah.

| Produk | Modal per unit | Harga jual per unit | Stok awal | Satuan | Tujuan |
| --- | ---: | ---: | ---: | --- | --- |
| Mie Demo | Rp 3.000 | Rp 5.000 | 10 | bungkus | Transaksi acuan |
| Air Demo | Rp 2.000 | Rp 3.000 | 20 | botol | Transaksi acuan |
| Produk Habis Demo | Rp 1.000 | Rp 2.000 | 0 | pcs | Uji stok habis |
| Produk CRUD Demo | Rp 1.000 | Rp 2.000 | 4 | pcs | Edit, tambah stok, filter, hapus |

Lakukan kedua transaksi sebagai **Kasir A** agar nama petugas juga dapat diperiksa.

| Nilai | Transaksi 1: 2 Mie + 3 Air | Transaksi 2: 1 Mie + 1 Air | Gabungan |
| --- | ---: | ---: | ---: |
| Total penjualan | Rp 19.000 | Rp 8.000 | Rp 27.000 |
| Modal barang terjual | Rp 12.000 | Rp 5.000 | Rp 17.000 |
| Laba kotor | Rp 7.000 | Rp 3.000 | Rp 10.000 |
| Jumlah unit terjual | 5 | 2 | 7 |
| Uang diterima | Rp 20.000 | Rp 8.000 | Bukan angka omzet laporan |
| Kembalian | Rp 1.000 | Rp 0 | Bukan pengurang laba |
| Sisa stok Mie | 8 | 7 | 7 |
| Sisa stok Air | 17 | 16 | 16 |
| Jumlah nota kumulatif | 1 | 2 | 2 |

Laba dihitung dari `(harga jual - modal) x jumlah`, bukan dari uang yang diserahkan pelanggan. Angka gabungan hanya berlaku jika belum ada transaksi lain pada toko/periode tersebut.

## A. Aplikasi dan koneksi

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| A01 | Jalankan preflight. | Auth sehat, signup tanpa konfirmasi aktif, RPC tersedia dan menolak anonim, function meminta login; **Preflight lulus**. |
| A02 | Buka aplikasi tanpa sesi tersimpan. | Halaman login tampil; tidak ada layar merah, data contoh toko lain, atau loading tanpa akhir. |
| A03 | Login lalu refresh browser pada URL dan port yang sama. | Akun dan role dipulihkan; permintaan data tetap mengikuti toko akun tersebut. Keranjang yang belum dibayar tidak diwajibkan bertahan. |

## B. Pendaftaran, login, dan sesi

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| B01 | Daftar Pemilik A dengan nama, nama toko, email baru, password minimal 8 karakter, dan konfirmasi sama. | Langsung masuk tanpa verifikasi email. Header memuat Toko Demo A, nama Pemilik, dan role **Pemilik**. |
| B02 | Periksa form daftar. | Tidak ada pilihan menaikkan role sendiri menjadi Kasir/Pemilik pada toko lama atau memilih toko milik orang lain. Signup publik membuat toko baru milik pendaftar. |
| B03 | Kosongkan nama Pemilik atau nama toko; coba juga hanya spasi. | **Wajib diisi.** Form tidak disimpan. |
| B04 | Masukkan nama lebih dari 100 karakter. | **Maksimal 100 karakter.** atau input dibatasi; tidak tersimpan melewati batas. |
| B05 | Isi email `budi`, `budi@`, atau kosong. | **Isi email yang benar.** |
| B06 | Isi password 7 karakter. | **Password minimal 8 karakter.** |
| B07 | Isi password lebih dari 128 karakter. | **Maksimal 128 karakter.** |
| B08 | Isi konfirmasi password berbeda. | **Password tidak sama.** Akun belum dibuat. |
| B09 | Daftar ulang dengan email yang sudah digunakan. | Ditolak; akun, toko, password, dan produk sebelumnya tidak berubah. Pesan aplikasi: **Email sudah digunakan. Silakan masuk atau gunakan email lain.** |
| B10 | Keluar, kemudian login menggunakan password salah. | **Email atau password salah.** Tidak masuk ke halaman toko. |
| B11 | Klik ikon mata pada field password. | Teks bisa ditampilkan/disembunyikan; nilainya tidak berubah. |
| B12 | Klik Keluar ketika keranjang berisi, lalu pilih Batal. | Tetap login; keranjang masih ada. |
| B13 | Klik Keluar, konfirmasi Keluar, lalu tekan Back. | Halaman login tampil; akun sebelumnya tidak dapat dipakai melalui Back. Login akun berikutnya mempunyai keranjang kosong. |
| B14 | Ganti akun A ke akun B melalui logout/login. | Header, menu, produk, dan transaksi mengikuti akun B; data maupun keranjang A tidak ikut. |

## C. Profil toko dan password sendiri

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| C01 | Pemilik membuka Pengaturan → Profil Toko, lalu menyimpan nama, alamat, dan telepon. | Kembali ke Pengaturan; saat kembali ke halaman utama, header menggunakan nama toko baru. Buka lagi/refresh: perubahan tetap ada. |
| C02 | Hapus nama toko atau isi hanya spasi. | **Wajib diisi.** Data toko sebelumnya tidak ditimpa. |
| C03 | Kosongkan alamat/telepon; uji batas alamat 300 dan telepon 30 karakter. | Keduanya opsional; input tidak boleh tersimpan melebihi batas. Ini bukan validasi bahwa nomor telepon benar-benar aktif. |
| C04 | Isi keranjang, lalu ubah profil toko dan kembali. | Keranjang tetap ada selama sesi dan totalnya tidak berubah hanya karena mengedit profil. |
| C05 | Pengaturan → Ganti Password; coba konfirmasi berbeda, kemudian simpan password valid yang berbeda dari sebelumnya. | Validasi gagal untuk konfirmasi berbeda; keberhasilan menampilkan **Password berhasil diubah.** Sesi dan keranjang tetap ada. |
| C06 | Logout setelah mengganti password; login memakai password lama lalu password baru. | Password lama ditolak; password baru berhasil. Ulangi untuk Pemilik dan Kasir. Tidak perlu mengharapkan semua sesi di perangkat lain langsung tertutup. |

## D. Pengelolaan Kasir

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| D01 | Pemilik membuka Pengaturan → Kelola Kasir saat daftar kosong. | **Belum ada Kasir. Tambahkan akun pertama.** |
| D02 | Tambah Kasir A dengan nama, email baru, password awal, dan konfirmasi sesuai. | Kembali ke daftar; nama/email benar dan status **Aktif**. Pemilik tetap login sebagai Pemilik. |
| D03 | Login Kasir A pada sesi browser terpisah. | Langsung bisa masuk tanpa verifikasi email; nama toko sama dengan Pemilik A, role **Kasir**. |
| D04 | Tambah Kasir dengan nama/email/password/konfirmasi tidak valid. | Validasi form tampil; tidak ada akun/profil tambahan. Aturan sama dengan form daftar. |
| D05 | Buat Kasir dengan email yang sudah dipakai Kasir lain, Pemilik, atau akun toko B. | **Email sudah digunakan. Gunakan email lain untuk akun Kasir.** Akun lama tidak ditimpa dan tidak dipindah toko. |
| D06 | Edit nama Kasir. | Nama tersimpan setelah muat ulang. Email tidak dapat diedit melalui form ini. Status aktif sebelumnya dipertahankan. |
| D07 | Pemilik mereset password Kasir ke password baru. | **Password berhasil diubah.** Pemilik tetap login; password Pemilik tidak berubah. |
| D08 | Logout Kasir, coba password lama lalu password hasil reset. | Lama ditolak; yang baru berhasil. |
| D09 | Pilih Nonaktifkan Kasir, lalu Batal. | Status tetap Aktif. |
| D10 | Konfirmasi nonaktifkan Kasir. | Status **Nonaktif**; akun/profil dan nota yang sudah dibuat tetap tersimpan. |
| D11 | Kasir sudah login pada sesi kedua; nonaktifkan dari Pemilik, lalu Kasir memuat ulang data/membayar. | Permintaan berikutnya ditolak dengan **Akun Kasir sudah dinonaktifkan. Hubungi Pemilik toko.** Penjualan gagal tidak membuat nota atau mengurangi stok. Layar lama tidak harus langsung hilang tanpa permintaan baru. |
| D12 | Coba login Kasir yang masih nonaktif. | Password bisa diterima oleh Auth, tetapi profil/akses toko ditolak dengan pesan akun dinonaktifkan; tidak mendapat akses operasional. |
| D13 | Pemilik mengaktifkan Kasir kembali, lalu Kasir mencoba akses/login lagi. | Status Aktif, akun yang sama dapat digunakan lagi; tidak terbentuk akun baru dan riwayat tetap ada. |

## E. Produk dan stok

Gunakan Produk CRUD Demo untuk perubahan pada bagian ini. Biarkan Mie Demo dan Air Demo pada harga serta stok awal sampai dua transaksi acuan selesai diperiksa.

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| E01 | Tambahkan empat produk contoh sesuai tabel persiapan. | Nama, modal, harga jual, stok, dan satuan sesuai; data tetap ada setelah refresh/login ulang. |
| E02 | Cari `mie`, lalu `MIE`. | Pencarian tidak membedakan huruf besar/kecil; Mie Demo ditemukan. |
| E03 | Cari nama yang tidak ada. | **Produk tidak ditemukan.** Tidak ada error aplikasi. |
| E04 | Pilih filter Menipis. | Hanya stok **1 sampai 5** yang tampil; Produk CRUD Demo dengan stok 4 termasuk. Stok 0 tidak termasuk Menipis. |
| E05 | Pilih filter Habis. | Hanya produk stok 0, termasuk Produk Habis Demo. |
| E06 | Buka detail Produk CRUD Demo sebagai Pemilik. | Harga jual, modal, stok/satuan tampil; tersedia Edit Produk, Tambah Stok, Hapus Produk. |
| E07 | Edit nama, harga/modal, dan satuan Produk CRUD Demo. | Perubahan tersimpan; stok tetap 4 karena edit metadata tidak mengubah stok. Field stok tidak tersedia pada Edit Produk. |
| E08 | Tambah stok sebanyak 3. | Stok menjadi **7**, bukan 3. Setelah refresh tetap 7 dan tidak lagi termasuk filter Menipis. |
| E09 | Tambah stok 0, negatif, kosong, atau bukan angka. | Ditolak; pesan **Jumlah stok harus lebih dari 0** untuk validasi form; stok tetap. |
| E10 | Simpan produk dengan nama/satuan kosong, angka negatif, atau angka bukan integer. | Ditolak; pesan **Semua data harus diisi dengan benar**. Tidak ada produk setengah tersimpan. |
| E11 | Coba nominal/stok `2147483648`, nama lebih dari 100, satuan lebih dari 20 karakter. | Form membatasi/menolak; backend tidak menerima angka di luar integer 32 bit. Data lama tetap. |
| E12 | Produk baru dengan stok 0. | Boleh tersimpan dan masuk Habis; tidak bisa ditambahkan untuk penjualan. Harga/modal 0 juga diperbolehkan oleh aturan saat ini. |
| E13 | Klik Hapus Produk lalu Batal. | Produk tetap di katalog dengan data yang sama. |
| E14 | Konfirmasi hapus Produk CRUD Demo. | Hilang dari katalog setelah muat ulang; produk lain dan laporan penjualan tidak berubah. |
| E15 | Setelah dua transaksi acuan, ubah harga/nama/modal Mie Demo; buka nota lama. | Rincian nama barang, harga jual, jumlah, subtotal, dan laba transaksi lama tetap memakai nilai saat penjualan. |
| E16 | Setelah pemeriksaan acuan, hapus produk yang sudah terjual; buka lagi nota lama. | Produk hilang dari katalog; nota dan rincian barang lama tetap ada. Laporan historis tidak berkurang karena penghapusan katalog. |

## F. Keranjang

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| F01 | Buka tab Kasir dengan keranjang kosong. | Total Rp 0 dan tombol Bayar tidak aktif. |
| F02 | Tambah 2 Mie Demo dan 3 Air Demo. | Kuantitas 2 dan 3; total **Rp 19.000**. Stok database masih 10 dan 20 karena belum dibayar. |
| F03 | Kurangi kuantitas sampai 0, lalu tambahkan lagi sesuai acuan. | Tidak menjadi negatif; item kuantitas 0 dikeluarkan dari keranjang. Total mengikuti isi terbaru. |
| F04 | Coba menambah Produk Habis Demo. | Tombol tambah tidak aktif/penambahan ditolak; tidak ada kuantitas positif untuk stok 0. |
| F05 | Coba menambah barang melebihi stok yang sedang dimuat. | Tombol tambah berhenti pada batas stok atau muncul **Stok tidak mencukupi.** |
| F06 | Pindah ke Produk/Riwayat lalu kembali ke Kasir tanpa logout/refresh browser. | Keranjang yang belum dibayar tetap ada dengan jumlah yang sama. |
| F07 | Cari barang di tab Kasir. | Pencarian menyaring daftar; barang yang tersembunyi oleh pencarian tetap dihitung jika sudah ada di keranjang. |
| F08 | Buka Pembayaran lalu kembali sebelum memproses. | Tidak ada nota baru; stok belum berkurang; keranjang tetap bisa diedit. |
| F09 | Stok berubah pada perangkat lain, lalu muat ulang produk. | Stok terbaru tampil. Jika kuantitas keranjang kini berlebih, muncul **Jumlah melebihi stok terbaru. Kurangi barang.** dan Bayar tidak aktif sampai diperbaiki. |

## G. Pembayaran dan dua transaksi acuan

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| G01 | Dari keranjang acuan pertama, tekan Bayar. | Rincian 2 Mie, 3 Air, dan total Rp 19.000 benar. |
| G02 | Kosongkan Uang Diterima lalu Proses Pembayaran. | Ditolak: **Isi uang pembayaran yang cukup, maksimal Rp 2.147.483.647.** Belum ada nota atau pengurangan stok. |
| G03 | Masukkan 18000. | **Kekurangan Rp 1.000**. Jika diproses, ditolak; stok dan jumlah nota tetap. |
| G04 | Klik Uang Pas. | Field menjadi 19000, kembalian Rp 0. Jangan proses dulu jika hendak mengikuti pembayaran acuan Rp 20.000. |
| G05 | Pilih Rp 20.000. | Field menjadi 20000, **Kembalian Rp 1.000**. |
| G06 | Coba huruf pada field uang dan nominal 2147483648. | Huruf tidak diterima oleh field; nominal melebihi batas ditolak sebelum transaksi tersimpan. |
| G07 | Proses transaksi pertama dengan Rp 20.000. | Tombol berubah **Memproses...**, lalu dialog **Pembayaran Berhasil**. Nomor nota terisi, total Rp 19.000, bayar Rp 20.000, kembalian Rp 1.000. |
| G08 | Pada keberhasilan transaksi 1, pilih Lihat Nota lalu kembali. | Detail nota sesuai pembayaran. Setelah alur selesai, keranjang kosong, stok Mie 8 dan Air 17. |
| G09 | Klik tombol proses berulang kali ketika permintaan sedang berjalan. | Tidak ada pembayaran ganda dari percobaan yang sama; hanya satu nota dan satu pengurangan stok. |
| G10 | Buat transaksi kedua: 1 Mie + 1 Air, pilih Uang Pas, proses. | Total Rp 8.000, bayar Rp 8.000, kembalian Rp 0; stok Mie 7 dan Air 16; total dua nota. |
| G11 | Pada transaksi kedua pilih Selesai. | Kembali ke Kasir tanpa wajib mencetak; keranjang kosong. Nota tetap tersedia pada Riwayat. |
| G12 | Muat ulang aplikasi dan buka lagi Riwayat, Produk, serta Laporan sebagai Pemilik. | Kedua transaksi, sisa stok 7/16, dan nilai laporan acuan tetap tersimpan. |

## H. Riwayat dan detail nota

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| H01 | Buka Riwayat setelah dua transaksi. | Dua nota berbeda, waktu masuk akal, petugas Kasir A; yang terbaru berada di atas. |
| H02 | Cari sebagian nomor nota transaksi pertama. | Nota yang cocok ditemukan; pencarian tidak mengubah data. |
| H03 | Cari nama Kasir A lalu nama yang tidak ada. | Nama yang cocok menyaring nota; pencarian tidak cocok memberikan keadaan kosong yang wajar. |
| H04 | Buka setiap nota. | Nama toko, nomor, tanggal/jam, petugas, rincian barang, total, tunai, dan kembalian sesuai acuan. Nomor nota bersifat unik; tidak perlu mengharapkan angka selalu tanpa lompatan. |
| H05 | Filter Semua, Hari ini, 7 hari terakhir, Bulan ini. | Hanya periode yang dipilih ditampilkan. Jika seluruh nota dibuat hari ini, filter-filter itu memang dapat menampilkan hasil sama. |
| H06 | Pilih Rentang tanggal yang mencakup hari transaksi; uji rentang satu hari dan periode tanpa transaksi. | Tanggal akhir yang dipilih ikut dihitung. Periode kosong menghasilkan daftar kosong, bukan crash. Untuk menguji pengecualian antarhari sungguhan, gunakan data uji dari hari berbeda. |
| H07 | Buka pemilih rentang tanggal lalu batalkan. | Filter/periode sebelumnya tetap dipakai, tidak berpindah ke rentang yang belum dipilih. |
| H08 | Lanjutan: siapkan lebih dari 50 nota uji dan tekan Muat Lebih Banyak. | Halaman berikutnya ditambahkan, nota tidak duplikat/hilang; pencarian atau pergantian periode memulai ulang daftar dari halaman pertama. |

## I. Laporan dan konsistensi angka

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| I01 | Sebagai Pemilik, buka Laporan sebelum penjualan pertama. | Transaksi, barang, penjualan, modal, dan laba bernilai 0. Menambah stok bukan transaksi penjualan. |
| I02 | Periksa laporan tepat setelah dua transaksi acuan, sebelum tes lain membuat nota. | **2 nota; 7 barang; penjualan Rp 27.000; modal Rp 17.000; laba kotor Rp 10.000.** |
| I03 | Bandingkan unit terjual dengan jumlah jenis barang. | Barang Terjual = **7 unit**, bukan 2 jenis produk. |
| I04 | Bandingkan omzet dan uang tunai yang diterima. | Omzet dari harga barang Rp 27.000; uang yang diterima Rp 28.000 dan kembalian Rp 1.000 tidak menambah omzet. |
| I05 | Pilih periode tanpa transaksi, lalu periode yang mencakup kedua nota. | Periode kosong bernilai 0; periode yang memuat keduanya kembali ke angka acuan. |
| I06 | Muat ulang setelah mengedit/hapus produk terjual. | Nilai laporan lama tetap berdasarkan snapshot transaksi, bukan harga atau keberadaan katalog terbaru. |
| I07 | Lanjutan: jual produk khusus dengan modal 5000, harga 4000, jumlah 1. | Aturan saat ini mengizinkan; laba transaksi -Rp 1.000. Jangan menilainya sebagai error hanya karena harga jual di bawah modal. Laba kotor belum dikurangi biaya operasional. |

## J. Hak akses melalui tampilan

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| J01 | Login Pemilik. | Tab **Kasir, Produk, Riwayat, Laporan**. Pengaturan memuat Profil Toko, Kelola Kasir, Ganti Password. |
| J02 | Login Kasir. | Tab **Kasir, Produk, Riwayat**. Tidak ada Laporan; Pengaturan hanya Ganti Password. |
| J03 | Kasir membuka detail produk. | Harga jual dan stok terlihat; modal tidak ditampilkan; tidak ada Edit, Tambah Stok, atau Hapus. Teks **Perubahan produk hanya dapat dilakukan oleh Pemilik.** |
| J04 | Kasir melihat Riwayat. | Boleh melihat transaksi seluruh Toko A, termasuk nota Pemilik/Kasir lain pada toko yang sama. Tidak dibatasi hanya nota dirinya. |
| J05 | Kasir membuka nota dan PDF. | Boleh melihat nominal penjualan/tunai/kembalian; nilai modal dan laba asli tidak ditampilkan. |
| J06 | Kasir membuka Daftar Harga. | Boleh membaca/mencetak daftar harga jual; tidak memperoleh daftar modal. |

## K. Dua toko dan pemisahan data

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| K01 | Daftar Pemilik B dengan email baru dan Toko Demo B pada sesi browser berbeda. | Toko baru mempunyai katalog, Kasir, riwayat, dan laporan kosong; data A tidak diwariskan. |
| K02 | Tambah Produk B Eksklusif pada B, lalu refresh A dan B. | Produk B hanya tampak pada B; Mie/Air Demo A hanya tampak pada A. |
| K03 | Buat transaksi B lalu periksa laporan A, dan sebaliknya. | Setiap toko hanya menghitung transaksi sendiri. |
| K04 | Buka Kelola Kasir pada A dan B. | Setiap Pemilik hanya melihat Kasir tokonya sendiri. Email yang sama tidak bisa dipakai ulang pada toko lain. |
| K05 | Ganti profil toko B, lalu buat PDF harga/nota pada A. | A tetap memakai identitas tokonya; tidak mengikuti nama toko B. |
| K06 | Logout A lalu login B pada jendela yang sama. | Tidak ada sisa katalog, nota, laporan, atau keranjang A di sesi B setelah data dimuat. |

## L. Gangguan jaringan dan dua perangkat

Kerjakan setelah laporan acuan dicatat. Buat produk khusus **Produk Balapan Demo**, modal 5000, harga 7000, stok 1, untuk uji stok terakhir.

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| L01 | Putus jaringan, lalu muat ulang data dari aplikasi yang sudah terbuka. | Pesan kegagalan yang bisa dibaca; halaman muat data menawarkan **Coba Lagi**. Tidak menganggap daftar kosong sebagai bukti data terhapus. Pesan umum: **Tidak dapat terhubung. Periksa koneksi dan coba lagi.** |
| L02 | Sambungkan jaringan lalu Coba Lagi/muat ulang. | Data dimuat kembali tanpa perlu menghapus akun atau membuat data ulang. |
| L03 | Putus jaringan sebelum menekan Proses Pembayaran. | Tidak ada keberhasilan palsu; jika request tidak sampai server, nota dan stok tetap. Ini belum menguji retry setelah server menyimpan transaksi. |
| L04 | Lanjutan: simulasikan respons pembayaran hilang setelah request terkirim, lalu retry pada layar Pembayaran yang sama. | Jika request pertama sudah disimpan, retry mengembalikan nota yang sama; hanya satu pengurangan stok. Buktikan melalui ID request/nota atau uji API pada bagian M. Jangan refresh/tutup layar karena ID retry tidak disimpan lintas restart aplikasi. |
| L05 | Sesi A sudah mempunyai keranjang; Pemilik pada sesi B mengubah harga jual salah satu barang sebelum A membayar. | A ditolak dengan **Harga produk berubah. Muat ulang keranjang.** Seluruh checkout gagal: tidak ada nota/penurunan stok sebagian pada barang lain. Kembali ke Kasir, muat ulang, lalu hitung ulang sebelum membayar. |
| L06 | Sesi A sudah mempunyai keranjang; sesi B menghabiskan/menghapus barang itu. | Checkout A ditolak karena stok tidak cukup/produk dihapus. Seluruh perubahan pembayaran A dibatalkan. |
| L07 | Dua sesi memuat Produk Balapan Demo stok 1 lalu membayar hampir bersamaan. | Tepat satu berhasil, satu ditolak; stok akhir 0, hanya satu nota sukses untuk unit itu; stok tidak negatif. |
| L08 | Dua sesi Pemilik yang sama menambah stok produk khusus bersamaan: stok awal 10, tambah 3 dan tambah 4. | Setelah muat ulang stok akhir 17, bukan 13/14. Jangan menjual produk itu selama pengujian penambahan. |
| L09 | Satu sesi membuka Edit Produk saat stok 10; sesi lain menjual 2; sesi pertama hanya mengubah nama/harga lalu Simpan. | Stok akhir tetap 8. Edit metadata tidak mengembalikan stok ke 10. |

## M. Uji backend langsung untuk akses dan manipulasi

Bagian lanjutan ini menggunakan klien API/Network DevTools dengan **publishable key dan token login akun uji yang sesuai**. Menghilangkan menu saja belum membuktikan pembatasan backend. SQL Editor Dashboard berjalan dengan hak pengelola, sehingga hasilnya bukan bukti bahwa token Kasir ditolak. Jangan memakai service/secret key sebagai pengganti token Kasir dalam uji izin.

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| M01 | Panggil `get_products`, `get_report`, atau RPC toko tanpa sesi pengguna. | Akses anonim ditolak, tidak ada data toko yang dikembalikan. Preflight juga memeriksa contoh pembatasan ini. |
| M02 | Baca tabel produk/profil/transaksi langsung sebagai anonim atau akun toko lain. | Tidak dapat memperoleh baris yang bukan haknya; hasil dapat berupa penolakan atau daftar kosong akibat RLS. HTTP 200 dengan daftar kosong bukan berarti semua data terbuka. |
| M03 | Gunakan token Kasir untuk `create_product`, `update_product`, `delete_product`, `add_product_stock`, `get_report`, `update_store`, `list_cashiers`, atau `update_cashier`. | Ditolak; data tidak berubah. Pesan backend **Fitur ini hanya untuk Pemilik.**, mapping Flutter **Akun tidak memiliki akses ke fitur ini.** |
| M04 | Panggil `manage-cashier` dengan apikey valid tetapi tanpa Authorization pengguna. | HTTP **401**, **Silakan masuk terlebih dahulu.** |
| M05 | Panggil function memakai Bearer token palsu/tidak valid. | HTTP **401**, **Sesi berakhir. Silakan masuk kembali.** |
| M06 | Panggil create/reset Kasir melalui function menggunakan token Kasir. | HTTP **403**, **Hanya Pemilik aktif yang dapat mengelola akun Kasir.** Tidak ada perubahan Auth Admin. |
| M07 | Pemilik B mengirim ID produk A ke edit/tambah stok/hapus, atau ID nota A ke detail nota. | **Produk tidak ditemukan di toko ini.** / **Transaksi tidak ditemukan.** Data A tidak terbaca/berubah. |
| M08 | Pemilik B mencoba reset password ID Kasir A; coba juga ID akun Pemilik. | HTTP **404**, **Akun Kasir tidak ditemukan di toko ini.** Password target tetap. |
| M09 | Sisipkan ID produk toko A pada checkout toko B, jumlah negatif/0, produk ganda, atau ubah expected total/harga. | Ditolak; tidak ada nota atau stok sebagian yang berubah. Total dan harga dipercaya setelah divalidasi backend, bukan sekadar nilai dari UI. |
| M10 | Kirim ulang checkout yang sudah sukses dengan `p_request_id` dan payload yang sama, menggunakan pengguna yang sama. | ID/nota yang sama dikembalikan; jumlah nota dan stok tidak berubah lagi. Untuk mencoba transaksi bisnis baru gunakan ID baru. |
| M11 | Akun berbeda mencoba memakai `p_request_id` milik transaksi pengguna pertama. | Ditolak **ID transaksi sudah digunakan.** Nota pengguna pertama tidak diambil alih. |
| M12 | Lihat respons katalog dan detail nota saat login Kasir. | `get_products` mengganti `cost_price` menjadi **0**, bukan modal asli. Nota Kasir tidak menyertakan `total_profit`, `cost_price`, atau `profit`. Jangan hanya mengecek apakah field disembunyikan UI. |

## N. Cetak dan PDF

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| N01 | Produk → Daftar Harga → Cetak Daftar Harga. | Dialog cetak/preview perangkat muncul; nama toko, produk, satuan, dan harga jual benar. Modal tidak ikut. |
| N02 | Simpan / Bagikan PDF daftar harga; buka file hasilnya. | PDF bisa dibuka dan berisi data, bukan halaman kosong. Chrome/Android dapat menampilkan dialog unduh/bagikan yang berbeda. |
| N03 | Detail transaksi → Cetak Nota dan Simpan / Bagikan PDF. | Nomor, petugas, waktu, barang, kuantitas, subtotal, total, tunai, dan kembalian sama dengan nota aplikasi. Tidak ada modal/laba pada PDF. |
| N04 | Batalkan dialog cetak/bagikan. | Kembali ke aplikasi; nota tidak hilang dan tidak tercipta pembayaran baru. |
| N05 | Lanjutan: katalog banyak produk sampai PDF lebih dari satu halaman. | Semua baris termuat, halaman terbaca, teks/tabel tidak terpotong di luar halaman. |
| N06 | Uji pada Android serta printer yang kompatibel jika akan didemokan. | Hasil dapat dicetak melalui layanan cetak perangkat. Keberhasilan PDF Chrome belum membuktikan printer Android/Bluetooth bekerja; integrasi ESC/POS khusus belum disertakan. |

## O. Navigasi dan tampilan

| ID | Langkah demo | Respons/hasil yang diharapkan |
| --- | --- | --- |
| O01 | Buka/kembali dari form, detail produk, Pengaturan, nota, dan pembayaran. | Kembali ke layar yang sesuai tanpa mengubah role atau toko; data belum disimpan tidak dianggap sukses. |
| O02 | Uji layar selebar 320 piksel, layar HP, dan desktop. | Tidak ada garis overflow kuning/hitam, teks penting hilang, tombol di luar layar tanpa scroll, atau layar merah. |
| O03 | Buka keyboard pada form panjang dan Pembayaran. | Field aktif, tombol Simpan/Bayar, serta pesan validasi tetap dapat dijangkau dengan scroll. |
| O04 | Saat operasi simpan/bayar berlangsung, tekan tombol yang sama berulang atau Back. | Tombol/loading mencegah permintaan ganda pada operasi yang dilindungi. Khusus pembayaran, Back diblokir selama Memproses agar hasil tidak ditinggalkan. |
| O05 | Login Kasir yang nonaktif, gagal memuat data, lalu gunakan pilihan Coba Lagi/Kembali ke Login yang tersedia. | Ada jalur pemulihan yang bisa dipakai; bukan layar loading permanen atau tampilan operasional tanpa akses. |

## Pemeriksaan angka lewat Supabase

Opsional untuk menguatkan bukti data tersimpan. Ambil ID Toko Demo A melalui Table Editor `stores`, lalu ganti `UUID_TOKO_A` pada query read-only berikut. Jalankan tepat setelah dua transaksi acuan, sebelum tes tambahan membuat nota.

```sql
select name, stock, cost_price, selling_price
from public.products
where store_id = 'UUID_TOKO_A'::uuid
order by name;

select
  count(*) as jumlah_nota,
  coalesce(sum(total_price), 0) as total_penjualan,
  coalesce(sum(total_price - total_profit), 0) as modal_terjual,
  coalesce(sum(total_profit), 0) as laba_kotor
from public.transactions
where store_id = 'UUID_TOKO_A'::uuid;

select coalesce(sum(i.qty), 0) as unit_terjual
from public.transaction_items i
join public.transactions t on t.id = i.transaction_id
where t.store_id = 'UUID_TOKO_A'::uuid;
```

Harapan: stok Mie **7**, Air **16**, jumlah nota **2**, penjualan **27000**, modal **17000**, laba **10000**, unit **7**. SQL di sini hanya untuk mencocokkan angka, bukan menguji izin role.

## Perilaku yang perlu dibedakan dari bug

- Refresh browser dapat memulihkan sesi login, tetapi keranjang belum dibayar hanya berada di memori. Keranjang tidak dijanjikan pulih setelah refresh/restart.
- Data antarperangkat dimuat ulang lewat refresh/Coba Lagi; tidak ada janji seluruh tampilan berubah secara realtime.
- Penonaktifan Kasir diperiksa saat request berikutnya. Layar lama yang masih terbuka tidak otomatis membuktikan akses backend masih diterima.
- Logout memakai scope perangkat/sesi lokal; bukan tombol logout semua perangkat.
- Reset/ganti password harus diuji lewat login baru. Jangan memakai harapan bahwa semua sesi lama seketika ditutup sebagai syarat lulus fitur ini.
- Nama toko dan nama Kasir pada pembacaan nota berasal dari data toko/profil terkini. Nota lama dapat mengikuti perubahan kedua nama itu. Yang disimpan sebagai snapshot adalah nama/harga/modal/jumlah barang dan nilai transaksi.
- Pencetakan ulang nota tidak membuat penjualan baru. Menghapus katalog tidak menghapus nota lama.
- Tidak ada fitur hapus permanen akun Kasir dari UI: gunakan Nonaktifkan/Aktifkan agar catatan transaksi tetap ada. Email Kasir tidak diedit melalui form.
- Harga dan modal nol serta harga jual di bawah modal diperbolehkan oleh aturan saat ini; laba negatif harus dihitung benar jika digunakan.
- Alur saat ini menggunakan pembayaran tunai. Lupa password Pemilik yang sudah logout, permintaan penghapusan akun/data publik, refund, pembayaran QRIS, dan integrasi printer Bluetooth ESC/POS khusus tidak termasuk fitur yang sudah disediakan.

## Mencatat hasil dan menentukan kelulusan

Gunakan status **Belum diuji**, **Lulus**, **Gagal**, atau **Terhambat**. Jangan menandai Lulus hanya karena halaman dapat dibuka.

| ID skenario | Hasil nyata | Status | Bukti/nomor nota |
| --- | --- | --- | --- |
| Contoh G07 | Isi setelah diuji | Belum diuji | Screenshot dialog dan ID/nota |
| Contoh I02 | Isi lima angka laporan | Belum diuji | Screenshot laporan / hasil SQL |
| Contoh L07 | Isi hasil dua sesi dan stok akhir | Belum diuji | Dua respons + stok database |

Masalah yang perlu diperbaiki sebelum demo alur utama: login/register gagal, sesi Pemilik berubah menjadi Kasir ketika membuat akun, akses lintas toko, Kasir memperoleh modal/laba asli atau operasi Pemilik, pembayaran gagal tetapi stok berubah, nota ganda dari retry yang sama, stok negatif, laporan tidak cocok, atau data hilang setelah refresh.

Uji dua perangkat, manipulasi API, dan printer harus dicatat Terhambat/Belum diuji bila belum dapat dilakukan. Lulus tes UI dan preflight bukan bukti semua uji keamanan, konkurensi, dan perangkat sudah dijalankan.

## Urutan presentasi singkat

1. Tunjukkan preflight lulus dan daftar Pemilik A tanpa konfirmasi email.
2. Edit profil toko, tambah produk contoh, serta tunjukkan pencarian dan filter stok.
3. Buat Kasir A sambil menunjukkan Pemilik tetap login.
4. Login Kasir A, bandingkan menu dengan Pemilik, lakukan transaksi 1 dan transaksi 2.
5. Tampilkan nota/PDF, stok sisa 7/16, dan laporan Pemilik 2 nota/7 unit/Rp 27.000/Rp 17.000/Rp 10.000.
6. Tampilkan Toko B yang tidak mendapat data A.
7. Nonaktifkan Kasir, tunjukkan request berikutnya ditolak, lalu aktifkan kembali.
8. Jika waktu/perangkat memungkinkan, tampilkan uji dua pembayaran untuk satu stok terakhir.
