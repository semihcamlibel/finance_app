import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'budget_page.dart';
import 'notification_test_page.dart';
import 'settings_page.dart';
import '../theme/app_theme.dart';

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
  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(key: _dashboardKey),
      const TransactionsPage(),
      const BudgetPage(),
      const NotificationTestPage(),
      SettingsPage(
        onThemeChanged: widget.onThemeChanged,
        onPrimaryColorChanged: widget.onPrimaryColorChanged,
      ),
    ];
  }

  void refreshNotifications() {
    if (_dashboardKey.currentState != null) {
      _dashboardKey.currentState!.refreshNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex != 0 // Dashboard'da AppBar gösterme
          ? AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(_getAppBarTitle()),
                ],
              ),
            )
          : null,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade900
              : Colors.white,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : null),
              selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryColor),
              label: 'Özet',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : null),
              selectedIcon:
                  Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              label: 'İşlemler',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : null),
              selectedIcon: Icon(Icons.account_balance_wallet,
                  color: AppTheme.primaryColor),
              label: 'Bütçe',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : null),
              selectedIcon:
                  Icon(Icons.notifications, color: AppTheme.primaryColor),
              label: 'Bildirimler',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey
                      : null),
              selectedIcon: Icon(Icons.settings, color: AppTheme.primaryColor),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Özet';
      case 1:
        return 'İşlemler';
      case 2:
        return 'Bütçe';
      case 3:
        return 'Bildirimler';
      case 4:
        return 'Ayarlar';
      default:
        return 'Finance App';
    }
  }
}
