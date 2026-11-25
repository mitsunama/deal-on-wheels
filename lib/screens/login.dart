import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widget/common.dart';
import 'create_account.dart';

class LoginScreen extends StatefulWidget {
  /// Why the visitor is being asked to log in (e.g. "Log in to list a vehicle").
  final String? message;
  const LoginScreen({super.key, this.message});

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(_email.text.trim(), _password.text);
      // The app is public, so this screen is a pushed route: go back to
      // whatever the visitor was doing.
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.directions_car_filled, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Deal on Wheels',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.message ?? 'Jual beli kendaraan',
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Masukkan email anda';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                          return 'Masukkan email yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Masukkan password anda' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Log in'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                              );
                              // Registering also logs the user in: go back too.
                              if (mounted && AuthService.instance.isLoggedIn) {
                                Navigator.of(context).pop(true);
                              }
                            },
                      child: const Text('Buat akun'),
                    ),
                    const SizedBox(height: 24),
                    Text('Server: ${api.baseUrl}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
