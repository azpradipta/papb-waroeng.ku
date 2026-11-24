import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/load_error.dart';
import 'privacy_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  final Profil profile;
  const AccountDeletionScreen({super.key, required this.profile});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  AccountDeletionRequest? _request;
  bool _loading = true;
  bool _failedToLoad = false;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failedToLoad = false;
      _error = null;
    });
    try {
      final request = await AppServices.of(
        context,
      ).auth.getAccountDeletionRequest();
      if (mounted) setState(() => _request = request);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _failedToLoad = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_confirmed || _busy || _request != null) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim permintaan penghapusan?'),
        content: Text(
          widget.profile.isPemilik
              ? 'Anda meminta penghapusan akun Pemilik, seluruh data toko, '
                    'dan semua akun Kasir yang terkait. Pengiriman permintaan '
                    'belum langsung menghapus akun dan data.'
              : 'Anda meminta penghapusan akun dan data pribadi sendiri. '
                    'Catatan penjualan toko disimpan tanpa identitas Anda. '
                    'Pengiriman permintaan belum langsung menghapus akun.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Kirim Permintaan'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await AppServices.of(
        context,
      ).auth.requestAccountDeletion();
      if (mounted) setState(() => _request = request);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Hapus Akun dan Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failedToLoad
          ? LoadError(message: _error!, onRetry: _load)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Permintaan untuk ${widget.profile.nama}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.profile.isPemilik
                          ? 'Sebagai Pemilik, permintaan Anda mencakup akun '
                                'dan data toko ${widget.profile.namaToko}. '
                                'Penghapusan mencakup semua akun Kasir yang '
                                'terkait, produk, stok, transaksi, dan laporan. '
                                'Simpan dokumen yang masih Anda butuhkan '
                                'sebelum pengelola memproses permintaan.'
                          : 'Permintaan Anda mencakup akun dan data pribadi '
                                'Anda sebagai Kasir. Data toko milik Pemilik '
                                'tidak otomatis dihapus. Catatan penjualan '
                                'toko dapat dipertahankan tanpa identitas '
                                'Anda.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ini adalah permintaan penghapusan, bukan penonaktifan '
                      'akun. Pengelola memeriksa dan memproses permintaan '
                      'secara manual, paling lambat 30 hari kalender setelah '
                      'verifikasi identitas yang diperlukan selesai. Akun '
                      'tetap tersedia sampai diproses.',
                    ),
                    const SizedBox(height: 24),
                    if (_request != null) ...[
                      Icon(
                        _request!.status == 'completed'
                            ? Icons.task_alt
                            : Icons.schedule_outlined,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(switch (_request!.status) {
                        'completed' => 'Permintaan telah selesai diproses.',
                        'processing' => 'Penghapusan sedang diproses.',
                        _ => 'Permintaan diterima dan menunggu diproses.',
                      }, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText('Nomor permintaan: ${_request!.id}'),
                      Text(
                        'Diajukan: ${MaterialLocalizations.of(context).formatMediumDate(_request!.requestedAt.toLocal())}',
                      ),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Perbarui Status'),
                      ),
                    ] else ...[
                      CheckboxListTile(
                        key: const Key('deletion-consent'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _confirmed,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _confirmed = value ?? false),
                        title: const Text(
                          'Saya memahami dampaknya dan ingin meminta '
                          'penghapusan akun serta data terkait.',
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      FilledButton(
                        onPressed: !_confirmed || _busy ? null : _submit,
                        child: Text(
                          _busy ? 'Mengirim...' : 'Kirim Permintaan Hapus Akun',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const PublicPrivacyContact(),
                  ],
                ),
              ),
            ),
    ),
  );
}
