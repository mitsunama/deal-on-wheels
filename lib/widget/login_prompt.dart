import 'package:flutter/material.dart';

import '../screens/login.dart';
import '../services/auth_service.dart';

/// Opens the login screen on top of whatever the visitor is looking at and
/// resolves to true once they are logged in (false if they backed out).
/// Browsing is public; call this only before a transaction (listing or buying).
Future<bool> requireLogin(BuildContext context, {String? message}) async {
  if (AuthService.instance.isLoggedIn) return true;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => LoginScreen(message: message)),
  );
  return AuthService.instance.isLoggedIn;
}

/// Shown in place of the Transactions / Profile tabs for visitors.
class LoginPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const LoginPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => requireLogin(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Login atau buat akun'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
