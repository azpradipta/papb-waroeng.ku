import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/account_fields.dart';
import '../widgets/load_error.dart';
import 'privacy_screen.dart';

class AccountDeletionScreen extends StatefulWidget {
  final Profil profile;
  const AccountDeletionScreen({super.key, required this.profile});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  AccountDeletionRequest? _request;
  bool _loading = true;
  bool _failedToLoad = false;
  bool _busy = false;
  bool _confirmed = false;
  bool _accepted = false;
  String? _error;

  bool get _canRequest => _request == null || _request!.status == 'pending';

  @override
  void initState() {
    super.initState();
    _password.addListener(_passwordChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _passwordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || _busy) return;
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
    if (_busy ||
        !_canRequest ||
        !_confirmed ||
        !_form.currentState!.validate()) {
      return;
    }
    final auth = AppServices.of(context).auth;
    // Kunci sejak dialog dibuka agar ketukan berulang tidak mengirim dua kali.
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var answered = false;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus akun secara permanen?'),
          content: Text(
            widget.profile.isPemilik
                ? 'Seluruh toko ${widget.profile.namaToko}, produk, stok, '
                      'transaksi, laporan, akun Anda, dan semua akun Kasir '
                      'terkait akan dihapus otomatis. Tindakan ini tidak '
                      'dapat dibatalkan.'
                : 'Akun dan data pribadi Anda akan dihapus otomatis. '
                      'Catatan penjualan toko dipertahankan tanpa identitas '
                      'Anda. Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (answered) return;
                answered = true;
                Navigator.pop(context, true);
              },
              child: const Text('Ya, Hapus Permanen'),
            ),
          ],
        ),
      );
      if (agreed != true || !mounted) return;
      final request = await auth.requestAccountDeletion(
        password: _password.text,
      );
      if (!mounted) return;
      _password.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _request = request;
        _accepted = true;
      });
      // Logout mengganti seluruh halaman dan keranjang; tampilkan hasil dahulu.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Permintaan diterima'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penghapusan akan diproses otomatis oleh server. '
                  'Akun belum dinyatakan selesai dihapus. Anda akan '
                  'dikeluarkan dari aplikasi.',
                ),
                const SizedBox(height: 12),
                SelectableText('Nomor permintaan: ${request.id}'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        ),
      );
      await auth.signOut();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    final auth = AppServices.of(context).auth;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.signOut();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_accepted,
    child: Scaffold(
      appBar: AppBar(title: const Text('Hapus Akun dan Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failedToLoad
          ? LoadError(message: _error!, onRetry: _load)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Penghapusan akun ${widget.profile.nama}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.profile.isPemilik
                            ? 'Sebagai Pemilik, penghapusan mencakup akun '
                                  'Anda dan seluruh data toko '
                                  '${widget.profile.namaToko}: semua akun '
                                  'Kasir terkait, produk, stok, transaksi, '
                                  'dan laporan. Simpan dokumen yang masih '
                                  'dibutuhkan sebelum melanjutkan.'
                            : 'Penghapusan mencakup akun dan data pribadi '
                                  'Anda sebagai Kasir. Data toko milik '
                                  'Pemilik tetap ada. Catatan penjualan '
                                  'dipertahankan tanpa identitas Anda.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Masukkan kembali password untuk memastikan '
                        'kepemilikan akun. Setelah dikonfirmasi, server '
                        'memproses penghapusan otomatis dan Anda keluar '
                        'dari aplikasi. Penghapusan bersifat permanen '
                        'dan tidak dapat dibatalkan.',
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
                          'processing' =>
                            'Penghapusan sedang diproses otomatis.',
                          _ =>
                            _accepted
                                ? 'Permintaan diterima untuk diproses otomatis.'
                                : 'Permintaan sebelumnya sudah tercatat. '
                                      'Konfirmasikan password di bawah untuk '
                                      'memulai pemrosesan otomatis.',
                        }, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText('Nomor permintaan: ${_request!.id}'),
                        Text(
                          'Diajukan: ${MaterialLocalizations.of(context).formatMediumDate(_request!.requestedAt.toLocal())}',
                        ),
                        if (!_accepted)
                          TextButton.icon(
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Perbarui Status'),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (_canRequest && !_accepted) ...[
                        PasswordField(
                          key: const Key('deletion-password'),
                          controller: _password,
                          label: 'Password akun saat ini',
                          enabled: !_busy,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Masukkan password akun Anda.'
                              : null,
                        ),
                        const SizedBox(height: 16),
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
                            'Saya memahami dampaknya dan menyetujui '
                            'penghapusan permanen akun serta data terkait.',
                          ),
                        ),
                        FilledButton(
                          onPressed:
                              !_confirmed || _password.text.isEmpty || _busy
                              ? null
                              : _submit,
                          child: Text(
                            _busy ? 'Mengirim...' : 'Hapus Akun Permanen',
                          ),
                        ),
                      ],
                      if (_accepted)
                        FilledButton(
                          onPressed: _busy ? null : _signOut,
                          child: Text(_busy ? 'Keluar...' : 'Kembali ke Login'),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const PublicPrivacyContact(),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
