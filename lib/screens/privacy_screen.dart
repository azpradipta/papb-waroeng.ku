import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/public_info_config.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kebijakan Privasi')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text(
              'Privasi di Waroeng.Ku',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _PrivacySection(
              title: 'Data yang digunakan',
              text:
                  'Waroeng.Ku menggunakan nama, email, dan informasi akun untuk '
                  'pendaftaran serta login. Data toko meliputi nama, alamat dan '
                  'telepon jika diisi, akun kasir, produk, harga, stok, serta '
                  'riwayat transaksi tunai. Aplikasi tidak meminta data kartu '
                  'pembayaran, lokasi perangkat, kontak, kamera, atau mikrofon.',
            ),
            _PrivacySection(
              title: 'Tujuan dan penyimpanan',
              text:
                  'Data dikirim melalui internet ke layanan Supabase untuk '
                  'autentikasi dan penyimpanan database. Data digunakan untuk '
                  'mengelola warung, mengatur akses Pemilik dan Kasir, '
                  'memproses penjualan, serta membuat laporan dan nota. Sesi '
                  'login disimpan pada perangkat agar Anda tidak perlu masuk '
                  'setiap kali membuka aplikasi. Keluar dari akun menghapus '
                  'sesi login lokal. Supabase juga dapat mencatat alamat IP, '
                  'user agent, waktu, dan aktivitas login untuk keamanan '
                  'serta operasional layanan.',
            ),
            _PrivacySection(
              title: 'Siapa yang dapat mengakses',
              text:
                  'Pemilik dapat mengelola data tokonya dan akun Kasir. Kasir '
                  'mendapat akses sesuai perannya. Pengelola aplikasi dan '
                  'penyedia layanan dapat memproses data untuk menjalankan '
                  'layanan dan menangani gangguan. Waroeng.Ku tidak memasang '
                  'iklan atau SDK analitik. Jika Anda membagikan PDF, data '
                  'dalam dokumen dikirim ke penerima atau aplikasi yang '
                  'Anda pilih.',
            ),
            _PrivacySection(
              title: 'Penyimpanan dan penghapusan',
              text:
                  'Data akun dan toko disimpan selama digunakan untuk '
                  'layanan. Anda dapat meminta penghapusan melalui Pengaturan '
                  '→ Hapus Akun dan Data. Anda memasukkan kembali password '
                  'dan mengonfirmasi dampaknya. Server memeriksa, mencatat, '
                  'dan memproses penghapusan secara otomatis. Proses dapat '
                  'berlanjut setelah Anda keluar dan diulang bila ada '
                  'gangguan. Penghapusan yang sudah dikonfirmasi tidak dapat '
                  'dibatalkan. Status diterima atau sedang diproses belum '
                  'berarti seluruh data selesai dihapus. '
                  'Permintaan Pemilik mencakup seluruh '
                  'data tokonya dan akun Kasir yang terkait. Untuk Kasir, '
                  'penghapusan data '
                  'pribadi tidak otomatis menghapus catatan penjualan toko. '
                  'Catatan transaksi disimpan dengan nama Kasir dihapus. '
                  'Jika proses otomatis mengalami gangguan atau permintaan '
                  'diajukan melalui email, pengelola membantu menyelesaikannya '
                  'paling lambat 30 hari kalender '
                  'setelah verifikasi identitas yang diperlukan selesai. '
                  'Salinan cadangan dan log teknis dapat tetap tersimpan '
                  'sampai masa retensi layanan atau konfigurasi pengelola '
                  'berakhir; penghapusan tidak membuat semua salinan '
                  'tersebut langsung hilang. '
                  'Jika tidak bisa login, gunakan jalur permintaan di luar '
                  'aplikasi atau hubungi pengelola.',
            ),
            PublicPrivacyContact(),
          ],
        ),
      ),
    ),
  );
}

class PublicPrivacyContact extends StatelessWidget {
  const PublicPrivacyContact({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (PublicInfoConfig.supportEmail.isNotEmpty)
        PublicContactLink(
          title: 'Kontak pengelola',
          value: PublicInfoConfig.supportEmail,
        ),
      if (PublicInfoConfig.privacyPolicyUrl.isNotEmpty)
        PublicContactLink(
          title: 'Kebijakan privasi di web',
          value: PublicInfoConfig.privacyPolicyUrl,
        ),
      if (PublicInfoConfig.accountDeletionUrl.isNotEmpty)
        PublicContactLink(
          title: 'Permintaan hapus akun melalui web',
          value: PublicInfoConfig.accountDeletionUrl,
        ),
    ],
  );
}

class PublicContactLink extends StatelessWidget {
  final String title;
  final String value;
  const PublicContactLink({
    super.key,
    required this.title,
    required this.value,
  });

  Future<void> _open(BuildContext context) async {
    final uri = value.contains('@') && !value.startsWith('https://')
        ? Uri(scheme: 'mailto', path: value)
        : Uri.parse(value);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Tautan tetap dapat digunakan jika perangkat tidak punya aplikasi pembuka.
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tautan disalin. Tempelkan di browser atau aplikasi email.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(child: SelectableText(value)),
            IconButton(
              tooltip: 'Buka $title',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _open(context),
            ),
            IconButton(
              tooltip: 'Salin $title',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tersalin ke papan klip.')),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String text;
  const _PrivacySection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(text),
      ],
    ),
  );
}
