# Bukti build release Waroeng.Ku

Build lokal berhasil pada **20 November 2026**. APK dan AAB sudah ditandatangani dengan keystore pribadi; tidak ada upload ke Play Store.

## Artefak yang dihasilkan

| Hasil | Lokasi | Ukuran |
| --- | --- | --- |
| APK untuk dipasang dan didemokan di HP | `build/app/outputs/flutter-apk/app-release.apk` | 24.765.347 byte, sekitar 23,6 MiB |
| Android App Bundle | `build/app/outputs/bundle/release/app-release.aab` | 44.161.654 byte, sekitar 42,1 MiB |

SHA-256 APK:

```text
574927a718e51255d06ed9e6245cf4b0ee53f1070611c47511fb9b0d9866bfeb
```

SHA-256 AAB:

```text
0ea471f850b7967996623ecb663b64e3cf6fb915ef5219fcc7f39b76e0e716a2
```

Hash mengidentifikasi file hasil build ini. Setelah membuat build baru, jalankan pemeriksaan lagi dan gunakan laporan hasil terbaru.

## Identitas dari APK sebenarnya

| Pemeriksaan | Hasil |
| --- | --- |
| Label | Waroeng.Ku |
| Application ID | `id.waroengku.kasir` |
| Activity launcher | `id.waroengku.kasir.MainActivity` |
| Version name dan code | `1.0.0` dan `1` |
| Debuggable | **false** |
| Minimum SDK dan target SDK | 21 dan 35 |
| Izin internet | Ada dalam manifest APK |
| Library kode release AOT | `libapp.so` untuk arm64-v8a, armeabi-v7a, dan x86_64 |
| Kernel kode debug | `kernel_blob.bin` tidak ditemukan |
| Signature APK | Lulus `apksigner verify`; sertifikat sama dengan keystore lokal |
| Signature AAB | Lulus `jarsigner -verify`; sertifikat sama dengan APK |
| Provider PDF | `id.waroengku.kasir.flutter.printing`, `exported=false` |
| Konfigurasi Supabase | URL dan publishable key yang diharapkan ditemukan dalam kode APK; nilainya tidak dicetak dalam laporan |
| Logo dan lisensi | Logo dibundel, NOTICES.Z terbaca, notice MaterialIcons dan Roboto ditemukan |

Sidik SHA-256 **sertifikat publik** penandatangan APK dan AAB:

```text
348c1874c2ce0de51c18ecc377f3d9227d30fe01b31f9c1e9f21e5d72139c38f
```

Sidik sertifikat berbeda dari hash file APK: sidik sertifikat mengenali kunci penandatangan, sedangkan hash APK mengenali file build. Sidik sertifikat akan tetap sama untuk pembaruan yang memakai key ini.

## Pemeriksaan yang telah dijalankan

- `flutter analyze`: tidak ada masalah.
- `flutter test`: **23 tes lulus**.
- `python tool/check_backend.py`: Auth HTTP 200, signup aktif, login tanpa verifikasi email aktif, RPC tersedia dan menolak akses anonim, fungsi kasir meminta login.
- `python tool/verify_release.py --java-home "D:\Android Studio\jbr"`: **12 dari 12 pemeriksaan lulus**.
- Pemeriksaan tambahan AAB: signature valid dan sidik sertifikat cocok dengan APK.
- Pemeriksaan isi kode APK: konfigurasi klien Supabase masuk ke hasil kompilasi.
- `git check-ignore`: keystore, `key.properties`, dan cache Gradle lokal diabaikan Git.
- `git diff --check`: lulus.

Laporan hasil pemeriksaan lokal:

```text
build/release-verification.json
build/bundle-verification.json
build/client-config-verification.json
```

## Pemeriksaan yang masih perlu dilakukan di perangkat

Tidak ada HP Android yang terhubung saat build. Pemasangan APK, tampilan splash di HP, login pengguna, transaksi pada backend aktif, dan dialog cetak Android belum dinyatakan lulus. Lakukan urutan demo pada [BUILD_RELEASE.md](BUILD_RELEASE.md), lalu gunakan skenario lengkap di [UJI_PENERIMAAN.md](UJI_PENERIMAAN.md).

Pastikan migrasi perbaikan Tambah Kasir sudah dijalankan pada Supabase cloud. Preflight backend tidak membuktikan migrasi trigger tersebut sudah terpasang.

Command-line Tools Android 19.0 sudah dipasang dari arsip resmi Google dan checksum arsip telah diverifikasi. `flutter doctor` mendeteksi alat tersebut; masih ada lisensi SDK yang menunggu persetujuan pengguna melalui `flutter doctor --android-licenses`.

Asal gambar dan notice pihak ketiga dicatat pada [ASET_DAN_LISENSI.md](ASET_DAN_LISENSI.md). Logo dibuat sendiri menurut konfirmasi pemilik project; pemeriksaan aset tidak menemukan konten dewasa. Ini belum merupakan rating umur resmi Play Store.

Toolchain build: Flutter 3.32.1, Dart 3.8.1, JDK 21.0.6, Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0. Android compile/target SDK 35; pemeriksa APK menggunakan Build-Tools 36.0.0 yang juga sudah tersedia di komputer.
