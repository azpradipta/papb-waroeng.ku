# Build release Android Waroeng.Ku

Panduan ini untuk membuat APK yang bisa dipasang dan dibuka langsung di HP Android saat presentasi PAPB. Project memakai Supabase cloud. APK tidak membutuhkan laptop, Chrome, Docker, atau `flutter run` setelah dipasang, tetapi membutuhkan internet untuk login dan mengakses data toko.

## Konfigurasi yang dipakai

| Komponen | Nilai project | Artinya |
| --- | --- | --- |
| Nama aplikasi | Waroeng.Ku | Nama di launcher HP. Berbeda dari nama folder/package Dart `waroeng_ku`. |
| Application ID | `id.waroengku.kasir` | Identitas instalasi Android, sudah menggantikan `com.example.waroeng_ku`. Ketersediaannya di Play Console baru diperiksa saat akan mendaftar aplikasi. |
| Namespace dan MainActivity | `id.waroengku.kasir` | Package kode Android disamakan agar launcher membuka activity yang benar. |
| Versi | `1.0.0+1` | `1.0.0` adalah versionName yang dibaca pengguna; `1` adalah versionCode internal Android. |
| Mode | `release` | Kode Dart dikompilasi untuk distribusi; hasil APK juga diperiksa agar tidak debuggable. |
| Signing | Konfigurasi `release`, alias `upload` | Memakai keystore pribadi, tidak lagi memakai kunci debug. |
| Permission utama | `android.permission.INTERNET` | Diperlukan untuk Supabase pada APK mandiri, bukan hanya saat debug. |
| Minimum dan target SDK | 21 dan 35 | APK menyatakan dukungan mulai Android 5.0, dengan target perilaku Android 15. Pengujian HP tetap diperlukan. |
| Ikon dan splash | Logo buatan pemilik project, warna oranye | Launcher, halaman login, dan splash memakai identitas Waroeng.Ku. Ada konfigurasi khusus Android 12 ke atas. |
| Backend | URL dan publishable key melalui `--dart-define-from-file=.env` | Konfigurasi ikut dikompilasi ke aplikasi; HP tidak membaca file `.env` dari laptop. |

Konfigurasi Android berada di `android/app/build.gradle.kts` karena project ini memakai Kotlin DSL. `pubspec.yaml` menyimpan versi. `android/app/src/main/AndroidManifest.xml` menyimpan nama, ikon, activity, dan izin internet.

Manifest APK juga mengandung permission internal `id.waroengku.kasir.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` dari AndroidX. Permission ini menjaga receiver internal; aplikasi tidak meminta akses kamera, lokasi, penyimpanan luas, atau Bluetooth untuk fitur yang sekarang.

## Kunci release yang sudah dibuat

Dua file berikut bersifat lokal dan diabaikan Git:

- `android/keystore/upload-keystore.jks`: menyimpan private key dan sertifikat untuk menandatangani aplikasi.
- `android/key.properties`: lokasi keystore, alias, dan password yang dibaca Gradle.

Kunci memakai RSA 2048 bit dan berlaku 10.000 hari. Nama sertifikat adalah Waroeng.Ku. Alias `upload` hanya nama entri kunci di dalam keystore, bukan perintah untuk mengunggah ke Play Store. Pada tahap ini kunci tersebut menandatangani APK untuk pemasangan langsung.

**Simpan backup kedua file tersebut di tempat pribadi yang aman di luar folder project.** Jangan mengunggahnya ke GitHub atau menampilkan password saat presentasi. Pembaruan APK yang dipasang langsung harus memakai kunci yang sama. File contoh yang aman diperlihatkan adalah `android/key.properties.example`.

Gradle membaca properti, memeriksa kelengkapannya saat build release, lalu menghubungkan `buildTypes.release` ke `signingConfigs.release`. Jika kunci hilang, build release berhenti dengan pesan yang jelas; tidak beralih ke debug key.

## Membuat APK lagi

Android SDK, Build-Tools, JDK Android Studio, dan Command-line Tools 19.0 sudah tersedia pada komputer ini. Untuk melengkapi persetujuan lisensi SDK yang masih ditandai oleh `flutter doctor`, jalankan:

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

Baca lisensi yang ditampilkan dan jawab `y` jika kamu menyetujuinya. Ini persetujuan penggunaan Android SDK pada komputer, bukan lisensi logo aplikasi dan bukan publikasi ke Play Store.

Jalankan dari PowerShell:

```powershell
cd D:\papbgacor\waroeng_ku
flutter pub get
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\build_release.ps1
```

Script menjalankan `flutter build apk --release --dart-define-from-file=.env`. Cache Gradle disimpan di `.tools/gradle` pada drive project agar tidak memakai cache C: yang sebelumnya bermasalah. Gradle dibatasi ke heap 2 GB dan dua worker; daemon tidak dibiarkan berjalan setelah build, sesuai laptop dengan RAM 8 GB. Script memulihkan environment setelah selesai. `ExecutionPolicy Bypass` hanya berlaku pada proses PowerShell tersebut, tidak mengubah kebijakan Windows secara permanen.

Hasil yang dipakai untuk demo:

```text
build/app/outputs/flutter-apk/app-release.apk
```

APK ini dibuat untuk beberapa arsitektur Android sehingga satu file mudah dibagikan untuk uji langsung. Folder `build/` adalah hasil build dan tidak masuk Git. `flutter clean` menghapus hasil build; buat ulang dengan perintah yang sama bila diperlukan.

Untuk membuat Android App Bundle sebagai latihan tahap berikutnya:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\build_release.ps1 -Target appbundle
```

Hasilnya `build/app/outputs/bundle/release/app-release.aab`. AAB adalah format untuk distribusi melalui toko aplikasi dan tidak dipasang langsung seperti APK. Tidak ada langkah upload atau deploy dalam script ini.

## Memastikan hasilnya benar

```powershell
flutter analyze
flutter test
python tool\check_backend.py
python tool\verify_release.py
```

Jika alat signing membutuhkan JDK Android Studio pada komputer ini:

```powershell
python tool\verify_release.py --java-home "D:\Android Studio\jbr"
```

Pemeriksa APK membaca identitas, versi, launcher, permission, flag debug, kode Flutter AOT, serta tanda tangan APK. Sidik SHA-256 sertifikat penandatangan dibandingkan langsung dengan sertifikat keystore lokal. Laporan nonrahasia disimpan di `build/release-verification.json`.

Menyembunyikan tulisan DEBUG pada layar saja bukan bukti mode release. Bukti yang ditunjukkan adalah perintah build `--release`, APK tidak debuggable, kode AOT, dan tanda tangan yang cocok dengan key pribadi. Sertifikat publik dan sidik SHA-256 aman ditampilkan; private key serta password tetap pribadi.

Preflight backend memeriksa kesehatan Auth, konfigurasi signup, RPC, dan akses anonim. Hasil lulus belum membuktikan seluruh transaksi pengguna sudah diuji di HP.

## Setup backend sebelum demo

Ikuti [SETUP_SUPABASE.md](SETUP_SUPABASE.md) untuk project Supabase yang dipakai `.env`. Pastikan tiga migrasi sudah dijalankan berurutan, termasuk `202611200001_cashier_auth_trigger.sql`, dan Edge Function `manage-cashier` sudah aktif. Migrasi terakhir memperbaiki pembuatan kasir yang sebelumnya gagal dengan pesan nama toko wajib diisi.

URL project dan publishable key boleh berada di aplikasi klien. Secret/service-role key hanya berada di server Edge Function, bukan di `.env` untuk Flutter. Build Android tidak memindahkan database Supabase ke HP; aplikasi tetap mengakses backend cloud yang sama.

## Memasang dan mencoba di HP

1. Salin `app-release.apk` ke HP Android sendiri melalui USB atau penyimpanan pribadi.
2. Buka file APK dan izinkan aplikasi pengelola file memasang APK tersebut jika Android meminta izin pemasangan dari sumber itu.
3. Selesaikan instalasi, kemudian buka **Waroeng.Ku dari ikon launcher**.
4. Hentikan `flutter run` di laptop jika sebelumnya berjalan. APK harus tetap dapat dibuka dan digunakan.
5. Sambungkan HP ke internet, lalu uji dengan akun demo dan data contoh.

Karena Application ID berubah, instalasi baru dapat muncul berdampingan dengan APK debug lama. Sesi login di instalasi lama tidak otomatis pindah, sedangkan data pada Supabase tetap tersimpan. Jika memperbarui aplikasi dengan ID sama, gunakan keystore yang sama dan versionCode lebih tinggi.

| Demo di HP | Langkah | Respons yang diharapkan |
| --- | --- | --- |
| Identitas | Lihat ikon launcher lalu buka aplikasi | Nama Waroeng.Ku, logo sendiri, splash oranye, masuk layar login atau sesi yang tersimpan. |
| Login | Masuk sebagai Pemilik | Data toko muncul; tab Kasir, Produk, Riwayat, dan Laporan tersedia. |
| Sesi | Tutup aplikasi sepenuhnya, lalu buka lagi | Sesi dimuat kembali dan data diambil dari Supabase. |
| Produk | Tambah produk demo, kemudian tambah stok | Produk dan stok tersimpan; setelah dimuat ulang nilainya sama. |
| Penjualan | Masukkan produk ke keranjang dan bayar tunai | Nota tercatat sekali, kembalian benar, stok berkurang, riwayat dan laporan sesuai. |
| Kasir | Pemilik membuat akun kasir; keluar lalu login dengan akun itu | Kasir masuk ke toko yang sama; menu khusus Pemilik tidak tersedia. |
| PDF | Buka nota atau daftar harga, lalu pilih cetak/bagikan | PDF terbentuk dan dialog Android terbuka. Cetak fisik tergantung printer yang tersedia. |
| Lisensi | Pengaturan → Lisensi Open Source | Daftar lisensi tampil, termasuk MaterialIcons dan Roboto. |
| Koneksi gagal | Matikan internet lalu muat ulang data | Pesan gagal yang dapat dicoba ulang muncul; aplikasi tidak menutup sendiri. Nyalakan internet lalu coba lagi. |
| Logout | Keluar, lalu buka lagi | Aplikasi kembali meminta login. |

Untuk angka uji penjualan yang sudah ditentukan dan pemeriksaan izin antar toko, gunakan [UJI_PENERIMAAN.md](UJI_PENERIMAAN.md).

## Bahan yang ditunjukkan saat presentasi

Urutan yang mudah diikuti:

1. Tunjukkan `pubspec.yaml`: jelaskan `1.0.0+1`.
2. Tunjukkan `android/app/build.gradle.kts`: Application ID final, pembacaan properti, signing release, dan `isDebuggable = false`.
3. Tunjukkan manifest utama: nama Waroeng.Ku, ikon, dan permission INTERNET.
4. Tunjukkan hasil build dan `build/release-verification.json`: sertifikat cocok serta debug false. Gunakan file contoh properti jika perlu menjelaskan password.
5. Buka APK yang sudah dipasang di HP dan demonstrasikan login, satu transaksi, serta PDF.
6. Jelaskan asal logo dan buka menu lisensi. Rinciannya ada di [ASET_DAN_LISENSI.md](ASET_DAN_LISENSI.md).

Contoh penjelasan singkat:

> Aplikasi saya bernama Waroeng.Ku untuk kasir dan pengelolaan toko. Application ID sudah menjadi id.waroengku.kasir. Versinya 1.0.0 dengan kode versi 1. APK dibuat dalam mode release dan ditandatangani keystore sendiri, lalu sertifikatnya saya verifikasi. Supabase dikonfigurasi saat build dan aplikasi memiliki izin internet. Logo saya buat sendiri; lisensi komponen lain tersedia di Pengaturan. APK ini dapat dipasang langsung di Android. Tahap progress ini belum mencakup publikasi ke Play Store.

## Versi berikutnya

Jika ada perubahan yang akan dibagikan sebagai pembaruan, ubah misalnya `version: 1.0.1+2`, lalu build dan periksa lagi. Pertahankan Application ID dan keystore untuk memperbarui instalasi yang sama.

## Rujukan resmi

- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Android: Sign your app](https://developer.android.com/studio/publish/app-signing)
- [Flutter: Android splash screen](https://docs.flutter.dev/platform-integration/android/splash-screen)

Toolchain project saat persiapan ini adalah Flutter 3.32.1 dan Dart 3.8.1. Build release untuk kelas belum berarti aplikasi sudah melalui pemeriksaan distribusi Play Store.
