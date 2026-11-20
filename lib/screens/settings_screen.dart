import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/account_fields.dart';
import '../widgets/load_error.dart';
import 'cashiers_screen.dart';
import 'password_screen.dart';

class SettingsScreen extends StatelessWidget {
  final Profil profile;
  const SettingsScreen({super.key, required this.profile});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(profile.nama),
          subtitle: Text(profile.role),
        ),
        if (profile.isPemilik) ...[
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Profil Toko'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Kelola Kasir'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CashiersScreen()),
            ),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Ganti Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PasswordScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Lisensi Open Source'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Waroeng.Ku',
          ),
        ),
      ],
    ),
  );
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  Toko? _store;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = await AppServices.of(context).shop.getStore();
      if (mounted) {
        _name.text = store.nama;
        _address.text = store.alamat;
        _phone.text = store.telepon;
        setState(() => _store = store);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).shop.updateStore(
        Toko(
          id: _store!.id,
          nama: _name.text,
          alamat: _address.text,
          telepon: _phone.text,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profil Toko')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _store == null
        ? LoadError(
            message: _error ?? 'Toko tidak dapat dimuat.',
            onRetry: _load,
          )
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Nama toko',
                        ),
                        validator: nameError,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _address,
                        enabled: !_busy,
                        maxLength: 300,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Alamat toko (opsional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phone,
                        enabled: !_busy,
                        maxLength: 30,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telepon toko (opsional)',
                        ),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Menyimpan...' : 'Simpan Toko'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
