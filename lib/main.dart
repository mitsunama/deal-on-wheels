import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'widget/navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init(); // restore saved session
  runApp(const DealOnWheelsApp());
}

class DealOnWheelsApp extends StatelessWidget {
  const DealOnWheelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deal on Wheels',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8590C)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const AuthGate(),
    );
  }
}

/// The main app is public: visitors can browse the showroom without an account.
/// Login is only requested before a transaction (see requireLogin). Login,
/// register, logout and expired tokens all just change AuthService.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        if (!auth.isReady) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // Keyed by user so switching accounts (or logging in/out) rebuilds
        // every tab from scratch.
        return MainNavigation(key: ValueKey(auth.user?.id ?? 'guest'));
      },
    );
  }
}
