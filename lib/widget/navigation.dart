import 'package:flutter/material.dart';

import '../screens/profile.dart';
import '../screens/showroom.dart';
import '../screens/transactions.dart';
import '../screens/wishlist.dart';
import '../services/auth_service.dart';
import 'login_prompt.dart';

/// Bottom navigation shell. Showroom is public; the Transactions and Profile
/// tabs ask visitors to log in.
///
/// Uses an IndexedStack so each tab keeps its scroll position and filters.
/// Tabs refetch through [AppEvents.dataVersion] when data changes elsewhere
/// (e.g. starting a deal on the vehicle page refreshes the Transactions tab).
class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppEvents.selectedTab,
      builder: (context, index, _) {
        final loggedIn = AuthService.instance.isLoggedIn;
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              const ShowroomScreen(),
              loggedIn
                  ? const WishlistScreen()
                  : const LoginPrompt(
                      icon: Icons.favorite_border,
                      title: 'Wishlist',
                      message: 'Login untuk melihat kendaraan yang Anda simpan.',
                    ),
              loggedIn
                  ? const TransactionsScreen()
                  : const LoginPrompt(
                      icon: Icons.receipt_long,
                      title: 'Transaksi',
                      message: 'Login untuk melihat transaksi Anda.',
                    ),
              loggedIn
                  ? const ProfileScreen()
                  : const LoginPrompt(
                      icon: Icons.person,
                      title: 'Profil',
                      message: 'Login untuk melihat dan mengubah profil Anda.',
                    ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => AppEvents.selectedTab.value = i,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Showroom',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Wishlist',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transaksi',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}
