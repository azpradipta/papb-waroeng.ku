import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/account_fields.dart';
import '../widgets/load_error.dart';
import 'password_screen.dart';

class CashiersScreen extends StatefulWidget {
  const CashiersScreen({super.key});
  @override
  State<CashiersScreen> createState() => _CashiersScreenState();
}

class _CashiersScreenState extends State<CashiersScreen> {
  List<AkunKasir> _rows = [];
  bool _loading = true;
  bool _busy = false;
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
      _error = null;
    });
    try {
      final rows = await AppServices.of(context).shop.getCashiers();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([AkunKasir? cashier]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CashierFormScreen(cashier: cashier)),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _toggle(AkunKasir cashier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(cashier.aktif ? 'Nonaktifkan Kasir?' : 'Aktifkan Kasir?'),
        content: Text(
          cashier.aktif
              ? '${cashier.nama} tidak dapat mengakses toko. Riwayat transaksi tetap tersimpan.'
              : '${cashier.nama} dapat mengakses toko kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppServices.of(context).shop.updateCashier(
        id: cashier.id,
        name: cashier.nama,
        active: !cashier.aktif,
      );
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola Kasir')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Tambah Kasir'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? LoadError(message: _error!, onRetry: _load)
        : _rows.isEmpty
        ? const Center(child: Text('Belum ada Kasir. Tambahkan akun pertama.'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final cashier = _rows[index];
                return ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    color: cashier.aktif ? Colors.orange : Colors.grey,
                  ),
                  title: Text(cashier.nama),
                  subtitle: Text(
                    '${cashier.email}\n${cashier.aktif ? 'Aktif' : 'Nonaktif'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _edit(cashier);
                      } else if (action == 'password') {
                        if (context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PasswordScreen(cashier: cashier),
                            ),
                          );
                        }
                      } else {
                        await _toggle(cashier);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Kasir'),
                      ),
                      const PopupMenuItem(
                        value: 'password',
                        child: Text('Reset Password'),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(cashier.aktif ? 'Nonaktifkan' : 'Aktifkan'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
  );
}

class CashierFormScreen extends StatefulWidget {
  final AkunKasir? cashier;
  const CashierFormScreen({super.key, this.cashier});
  @override
  State<CashierFormScreen> createState() => _CashierFormScreenState();
}

class _CashierFormScreenState extends State<CashierFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name.text = widget.cashier?.nama ?? '';
    _email.text = widget.cashier?.email ?? '';
  }

  @override
  void dispose() {
    for (final field in [_name, _email, _password, _confirm]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shop = AppServices.of(context).shop;
      final cashier = widget.cashier;
      if (cashier == null) {
        await shop.createCashier(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await shop.updateCashier(
          id: cashier.id,
          name: _name.text,
          active: cashier.aktif,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.cashier == null ? 'Tambah Kasir' : 'Edit Kasir'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Nama Kasir'),
                  validator: nameError,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  enabled: !_busy && widget.cashier == null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: emailError,
                ),
                if (widget.cashier == null) ...[
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    enabled: !_busy,
                    label: 'Password awal',
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    enabled: !_busy,
                    label: 'Konfirmasi password',
                    validator: (value) => value != _password.text
                        ? 'Password tidak sama.'
                        : passwordError(value),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Menyimpan...' : 'Simpan Kasir'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
