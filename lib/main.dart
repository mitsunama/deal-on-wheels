import 'package:flutter/material.dart';

import 'screens/login.dart';
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

/// Shows the login screen or the main app depending on the session.
/// Login, register, logout and expired tokens all just change AuthService,
/// so no screen needs to navigate manually.
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
        if (auth.isLoggedIn) {
          // Keyed by user so switching accounts rebuilds every tab from scratch.
          return NavigationPage(key: ValueKey(auth.user!.id));
        }
        return const LoginPage();
      },
    );
  }
}
