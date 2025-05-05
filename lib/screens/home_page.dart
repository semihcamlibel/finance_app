import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'budget_page.dart';
import 'notification_test_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(Color) onPrimaryColorChanged;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.onPrimaryColorChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardPage(),
      const TransactionsPage(),
      const BudgetPage(),
      const NotificationTestPage(),
      SettingsPage(
        onThemeChanged: widget.onThemeChanged,
        onPrimaryColorChanged: widget.onPrimaryColorChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans Takip'),
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Özet',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'İşlemler',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Bütçe',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Bildirimler',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
