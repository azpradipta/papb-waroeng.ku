import 'package:flutter/material.dart';
import '../data.dart';
import '../services/api_exception.dart';
import '../services/app_services.dart';
import '../widgets/account_fields.dart';

class PasswordScreen extends StatefulWidget {
  final AkunKasir? cashier;
  const PasswordScreen({super.key, this.cashier});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final services = AppServices.of(context);
      final cashier = widget.cashier;
      if (cashier == null) {
        await services.auth.changePassword(_password.text);
      } else {
        await services.shop.resetCashierPassword(cashier.id, _password.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diubah.')),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.cashier == null ? 'Ganti Password' : 'Reset Password Kasir',
      ),
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
                if (widget.cashier != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      '${widget.cashier!.nama}\n${widget.cashier!.email}',
                    ),
                  ),
                PasswordField(
                  controller: _password,
                  enabled: !_busy,
                  label: 'Password baru',
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
                  child: Text(_busy ? 'Menyimpan...' : 'Simpan Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
