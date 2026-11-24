import 'package:flutter/material.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/account_fields.dart';
import 'privacy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _store = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final field in [_name, _store, _email, _password, _confirm]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).auth.register(
        name: _name.text,
        storeName: _store.text,
        email: _email.text,
        password: _password.text,
      );
      // Perubahan sesi membuka halaman utama dan membuang halaman daftar.
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daftar Pemilik')),
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
                const Text(
                  'Buka toko Anda',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Daftar sebagai Pemilik, lalu tambahkan Kasir dari pengaturan toko.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('register-name'),
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Nama pemilik'),
                  validator: nameError,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register-store'),
                  controller: _store,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Nama toko'),
                  validator: nameError,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register-email'),
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: emailError,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('register-password'),
                  controller: _password,
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('register-confirm'),
                  controller: _confirm,
                  enabled: !_busy,
                  label: 'Konfirmasi password',
                  validator: (value) => value != _password.text
                      ? 'Password tidak sama.'
                      : passwordError(value),
                ),
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
                  onPressed: _busy ? null : _register,
                  child: Text(
                    _busy ? 'Membuat toko...' : 'Daftar dan Buka Toko',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyScreen(),
                    ),
                  ),
                  child: const Text('Kebijakan Privasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
