import 'package:flutter/material.dart';
import '../screens/showroom.dart';
import '../screens/transactions.dart';
import '../screens/profile.dart';
import '../services/auth_service.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppEvents.selectedTab,
      builder: (context, index, _) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: const [
              ShowroomPage(),
              TransactionsPage(),
              ProfilePage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => AppEvents.selectedTab.value = i,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Showroom',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
