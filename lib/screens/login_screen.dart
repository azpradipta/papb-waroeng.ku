import 'package:flutter/material.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import 'register_screen.dart';
import 'privacy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).auth.signIn(_email.text, _password.text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 110,
                        height: 110,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waroeng.Ku',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF7A29),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk dengan akun warung Anda',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('email'),
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        value == null || !value.trim().contains('@')
                        ? 'Isi email yang benar.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: 'Tampilkan atau sembunyikan password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Isi password.' : null,
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
                    onPressed: _busy ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_busy ? 'Memeriksa akun...' : 'Masuk'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                    child: const Text('Belum punya toko? Daftar Pemilik'),
                  ),
                  const Text(
                    'Akun Kasir dibuat oleh Pemilik toko.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
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
    ),
  );
}
