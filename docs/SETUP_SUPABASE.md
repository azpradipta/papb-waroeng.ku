# Setup Supabase Waroeng.Ku

Alur aplikasi: Pemilik mendaftar dengan nama, nama toko, email, dan password lalu langsung masuk. Pemilik membuat akun Kasir melalui Pengaturan → Kelola Kasir. Tidak ada verifikasi email, undangan, Google login, atau pembuatan akun manual di Dashboard untuk penggunaan normal.

Supabase cloud dipakai sebagai backend. Docker, Supabase lokal, Node.js, dan Deno tidak diperlukan untuk menjalankan aplikasi; Node.js hanya diperlukan jika ingin menjalankan tes database lokal.

## 1. Pilih project dan atur Auth

1. Buka [Supabase Dashboard](https://supabase.com/dashboard), pilih project untuk aplikasi ini. Project yang sudah dipakai pada `.env` bisa dilanjutkan.
2. Buka Authentication → Sign In / Providers. Pada beberapa tampilan pengaturan umum berada di User Signups.
3. Aktifkan **Allow new users to sign up**.
4. Pastikan provider **Email** aktif dan **Confirm Email** dimatikan, lalu simpan.
5. Atur panjang minimum password menjadi **8 karakter**. Aplikasi menerima 8–128 karakter.
6. Provider Google tidak perlu diaktifkan. Tidak ada konfigurasi SMTP yang diperlukan untuk alur daftar, login, buat Kasir, reset password Kasir oleh Pemilik, dan ganti password saat sudah login.

Pengaturan Confirm Email yang dimatikan berlaku untuk akun baru. Akun uji lama yang belum confirmed perlu dikonfirmasi dari Authentication → Users sebelum dipakai. Fitur lupa password Pemilik melalui email belum disertakan.

[Dokumentasi pengaturan Auth](https://supabase.com/docs/guides/auth/general-configuration).

## 2. Jalankan dua migrasi SQL secara berurutan

Buka **SQL Editor → New query**. Salin seluruh isi file pertama, jalankan, lalu buat query baru untuk file kedua:

1. [202611170001_complete_shop.sql](../supabase/migrations/202611170001_complete_shop.sql): skema produk, transaksi, profil, dan fungsi penjualan dasar.
2. [202611180001_stores_and_accounts.sql](../supabase/migrations/202611180001_stores_and_accounts.sql): toko, pendaftaran Pemilik, pengelolaan Kasir, dan pembatasan data per toko.

Jika migrasi pertama pernah dijalankan dan aplikasi sudah memakai skema dasarnya, cukup jalankan migrasi kedua. **Setelah migrasi kedua aktif, jangan jalankan migrasi pertama sendirian lagi** karena definisi fungsi versi lama belum membatasi toko. Untuk instalasi ulang dari awal, urutannya tetap pertama lalu kedua.

Setelah berhasil, Table Editor menampilkan `stores`, `profiles`, `products`, `transactions`, dan `transaction_items`. RLS, trigger akun, dan fungsi backend diatur oleh migrasi. Jangan membuka policy semua data untuk anon/authenticated secara manual.

Data lama tidak dihapus. Jika sudah ada tepat satu Pemilik, data versi satu-warung dihubungkan ke tokonya. Jika ada beberapa Pemilik lama, migrasi berhenti agar pembagian data tidak ditebak; tentukan satu Pemilik data lama terlebih dulu. Data lama tanpa Pemilik disimpan pada toko terpisah bernama Toko Lama; lihat bagian pemindahan data lama di bawah.

## 3. Deploy fungsi manage-cashier

Fungsi ini diperlukan untuk **membuat akun Kasir dan mereset password Kasir**. Membaca, mengedit nama, serta mengaktifkan/nonaktifkan Kasir menggunakan RPC database.

Melalui Dashboard:

1. Buka **Edge Functions → Deploy a new function → Via Editor**.
2. Beri nama fungsi persis **`manage-cashier`**.
3. Ganti isi `index.ts` dengan [index.ts](../supabase/functions/manage-cashier/index.ts).
4. Tambahkan file **`handler.mjs`** pada folder yang sama di editor. Isi dengan [handler.mjs](../supabase/functions/manage-cashier/handler.mjs). Nama dan ekstensi file harus sama karena diimpor oleh `index.ts`.
5. Tambahkan **`deno.json`** pada folder yang sama. Isi dengan [deno.json](../supabase/functions/manage-cashier/deno.json); file ini menentukan versi paket Supabase dan alias impor yang dipakai `index.ts`.
6. Deploy ketiga file: `index.ts`, `handler.mjs`, dan `deno.json`. Jika fungsi sudah pernah di-deploy, perbarui `index.ts` dan tambahkan `deno.json`, lalu pilih **Deploy updates**.
7. Pada pengaturan fungsi, matikan **Verify JWT / Enforce JWT verification** untuk fungsi ini, sesuai `supabase/config.toml`. Handler tetap memverifikasi Bearer token ke Auth server menggunakan `getUser()` dan memeriksa profil Pemilik aktif serta toko sebelum memakai Auth Admin. Request tanpa login ditolak dengan HTTP 401.

Runtime Supabase menyediakan `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEYS`, dan `SUPABASE_SECRET_KEYS`. Kode juga mendukung variabel bawaan lama `SUPABASE_ANON_KEY` dan `SUPABASE_SERVICE_ROLE_KEY`. Gunakan project dengan key bernama `default`, atau pertahankan key bawaan legacy yang masih aktif. Secret key hanya berada di runtime fungsi, **tidak dimasukkan ke `.env` Flutter**.

Alternatif bila Supabase CLI sudah tersedia:

```powershell
supabase login
supabase link --project-ref PROJECT_REF_KAMU
supabase functions deploy manage-cashier --no-verify-jwt
```

Deploy remote tidak memerlukan menyalakan Docker. Jangan menjalankan `supabase start` untuk mengikuti panduan cloud ini.

[Panduan editor fungsi](https://supabase.com/docs/guides/functions/quickstart-dashboard), [dependensi fungsi](https://supabase.com/docs/guides/functions/dependencies), [konfigurasi fungsi](https://supabase.com/docs/guides/functions/function-configuration), [variabel key](https://supabase.com/docs/guides/getting-started/api-keys).

### Jika file backend bergaris merah di VS Code

`index.ts` dan `handler.mjs` merupakan backend Deno. Pesan seperti `Cannot find name 'Deno'` atau impor `npm:@supabase/supabase-js@2` tidak dikenali muncul jika editor masih memakai pemeriksa TypeScript biasa.

Pengaturan `.vscode/settings.json` mengaktifkan Deno hanya untuk `supabase/functions`. Pasang ekstensi resmi **Deno** (`denoland.vscode-deno`), lalu jalankan **Developer: Reload Window** melalui Ctrl+Shift+P.

Ekstensi Deno meminta persetujuan ketika project menetapkan executable sendiri melalui `deno.path`. Pada notifikasi **A workspace setting wants to run a custom Deno executable: ./.tools/deno/deno.exe**, pilih **Allow** agar pemeriksa Deno mulai berjalan. Jika notifikasinya tersembunyi, jalankan **Notifications: Show Notifications** melalui Ctrl+Shift+P. Jika tadi memilih Deny, muat ulang jendela untuk menampilkan permintaan lagi. Garis merah dengan sumber `ts(2304)` atau `ts(2307)` masih berasal dari pemeriksa TypeScript bawaan, bukan Deno.

Pengaturan project menunjuk executable lokal `.tools/deno/deno.exe` dan menyimpan cache di `.tools/deno-cache`; folder ini tidak masuk Git. Pada komputer baru, [pasang Deno](https://docs.deno.com/runtime/getting_started/installation/) dan sesuaikan `deno.path` dengan lokasi executable-nya. Jika Deno sudah tersedia melalui PATH, hapus pengaturan `deno.path` agar ekstensi menemukannya otomatis. Deno hanya diperlukan untuk pemeriksaan kode backend di editor; aplikasi tetap menggunakan Supabase cloud.

Pesan **`not-installed-npm`** dengan sumber **`deno`** berarti dependensi belum tersedia untuk pemeriksa Deno. Fungsi ini mendeklarasikan paketnya di `supabase/functions/manage-cashier/deno.json`, sedangkan `deno.lock` menyimpan versi dan checksum hasil instalasi. Untuk menyiapkan ulang dependensi pada salinan lokal ini, jalankan dari root project:

```powershell
$env:DENO_DIR = Join-Path $PWD '.tools/deno-cache'
& .\.tools\deno\deno.exe install --config supabase/functions/manage-cashier/deno.json
```

Jika memakai instalasi Deno melalui PATH, gunakan `deno install --config supabase/functions/manage-cashier/deno.json` setelah mengatur cache yang sama dengan `deno.cache` di VS Code. Setelah instalasi, jalankan **Deno: Restart Language Server** melalui Ctrl+Shift+P. Folder `node_modules` tidak diperlukan untuk fungsi ini karena `nodeModulesDir` diatur ke `none`.

[Panduan dukungan Deno di VS Code](https://docs.deno.com/runtime/reference/vscode/).

## 4. Isi konfigurasi Flutter

Gunakan `.env` yang sudah ada jika project-nya sama. Jika belum ada, salin `.env.example` menjadi `.env` dan isi:

```env
SUPABASE_URL=https://PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_ISI_KEY_KAMU
```

Project URL dan publishable key tersedia pada dialog **Connect** atau pengaturan API Keys. Jangan gunakan secret/service_role key sebagai konfigurasi aplikasi. `.env` diabaikan Git.

## 5. Periksa backend lalu jalankan di Chrome

```powershell
cd D:\papbgacor\waroeng_ku
python tool\check_backend.py
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

Pemeriksaan backend bersifat read-only: mengecek Auth, pengaturan signup tanpa verifikasi, keberadaan RPC dengan akses anonim ditolak, dan fungsi `manage-cashier` yang meminta login. Hasil akhir yang diharapkan: **Preflight lulus**. Ini belum menguji pembuatan akun/penjualan sungguhan.

Jika konfigurasi `.env` berubah, hentikan proses Flutter dan jalankan ulang; hot reload tidak mengganti dart-define.

## 6. Coba alur pengguna

1. Pada login pilih **Belum punya toko? Daftar Pemilik**.
2. Isi nama, nama toko, email, password minimal 8 karakter, dan konfirmasi. Sesudah daftar berhasil, halaman utama menampilkan nama toko dan peran Pemilik.
3. Buka ikon **Pengaturan → Profil Toko** untuk mengisi alamat/telepon atau mengganti nama toko.
4. Buka **Pengaturan → Kelola Kasir → Tambah Kasir**. Isi nama, email berbeda, password awal dan konfirmasi.
5. Pastikan sesi tetap milik Pemilik. Berikan email dan password awal kepada pegawai.
6. Keluar, masuk menggunakan akun Kasir. Kasir dapat menjual dan membaca produk/riwayat toko; tidak dapat mengelola produk, laporan, toko, atau pegawai.
7. Kasir dapat membuka **Pengaturan → Ganti Password**. Pemilik dapat mereset password Kasir dari menu daftar Kasir.
8. Pemilik dapat menonaktifkan dan mengaktifkan kembali Kasir. Penonaktifan langsung menolak operasi database berikutnya, termasuk dari sesi yang masih login. Riwayat transaksi tidak dihapus.
9. Daftarkan Pemilik kedua untuk toko berbeda. Produk, nota, laporan, dan pegawainya harus terpisah dari toko pertama.

Email akun unik untuk satu project Supabase. Versi ini memakai satu akun untuk satu toko dan satu Pemilik untuk satu toko. Email Kasir tidak diedit melalui form; jika pegawai berganti email, nonaktifkan akun lama dan buat akun baru.

## Opsional: hubungkan data lama tanpa Pemilik

Lewati bagian ini untuk project baru atau toko lama yang sudah mempunyai Pemilik. Gunakan hanya jika data warung lama memang milik Pemilik yang kamu pilih. Buat/masuk akun yang akan menjadi Pemilik, lalu jalankan SQL berikut sebagai pengelola Dashboard setelah mengganti emailnya:

```sql
do $$
declare v_user uuid; v_target uuid; v_owner uuid; v_legacy uuid;
begin
  select p.id, p.store_id, s.owner_id into v_user, v_target, v_owner
  from public.profiles p join auth.users u on u.id = p.id
  join public.stores s on s.id = p.store_id
  where u.email = 'EMAIL_PEMILIK_YANG_DIPILIH';
  if v_user is null then raise exception 'Email tidak ditemukan.'; end if;
  if v_owner is not null and v_owner <> v_user then
    raise exception 'Akun ini terikat pada toko Pemilik lain.';
  end if;
  update public.stores set owner_id = v_user where id = v_target;
  update public.profiles set role = 'Pemilik', is_active = true where id = v_user;
  for v_legacy in select id from public.stores where owner_id is null
  loop
    update public.products set store_id = v_target where store_id = v_legacy;
    update public.transactions set store_id = v_target where store_id = v_legacy;
    update public.profiles set store_id = v_target where store_id = v_legacy;
    delete from public.stores where id = v_legacy;
  end loop;
end;
$$;
```

Keluar dan masuk kembali setelah pemindahan. SQL ini tidak menghapus produk, akun, atau transaksi; hanya menggabungkan toko lama yang belum mempunyai Pemilik ke toko tujuan.

## Jika ada error

| Gejala | Yang diperiksa |
| --- | --- |
| RPC HTTP 404 / PGRST202 | Kedua migrasi sudah dijalankan pada project yang sama dengan `.env` |
| Daftar tidak langsung masuk / email_not_confirmed | Confirm Email dimatikan; akun lama mungkin masih perlu diaktifkan di Dashboard |
| Pendaftaran belum dibuka | Allow new users to sign up diaktifkan |
| Tambah/reset Kasir belum tersedia | Deploy `manage-cashier` dengan `index.ts`, `handler.mjs`, dan `deno.json`; periksa log fungsi |
| Invalid JWT dari gateway | Verify JWT fungsi dimatikan sesuai config; handler tetap memeriksa token sendiri |
| Email sudah digunakan | Gunakan email lain; akun lama tidak ditimpa otomatis |
| Toko lama belum dihubungkan | Ikuti bagian pemindahan data lama di atas |

Lihat [UJI_PENERIMAAN.md](UJI_PENERIMAAN.md) untuk pengujian perangkat dan penjualan. Sebelum rilis Play Store, pemulihan akun Pemilik dan alur permintaan penghapusan akun/data perlu disiapkan terpisah dari fitur penonaktifan Kasir.
