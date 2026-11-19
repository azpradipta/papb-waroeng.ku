import 'package:flutter/material.dart';

String? nameError(String? value) => value == null || value.trim().isEmpty
    ? 'Wajib diisi.'
    : value.trim().length > 100
    ? 'Maksimal 100 karakter.'
    : null;
String? emailError(String? value) =>
    value == null ||
        value.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Isi email yang benar.'
    : null;
String? passwordError(String? value) => value == null || value.length < 8
    ? 'Password minimal 8 karakter.'
    : value.length > 128
    ? 'Maksimal 128 karakter.'
    : null;

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.enabled = true,
    this.validator,
  });
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: 'Tampilkan atau sembunyikan password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      ),
    ),
    validator: widget.validator ?? passwordError,
  );
}
