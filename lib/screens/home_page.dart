import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'finance_page.dart';
import 'accounts_list_page.dart';
import 'notification_test_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(Color) onPrimaryColorChanged;

  const HomePage({
    Key? key,
    required this.onThemeChanged,
    required this.onPrimaryColorChanged,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _refreshDashboard = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        actions: [
          // Bildirimleri test etme sayfasına yönlendirme butonu
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationTestPage(),
                ),
              );
            },
          )
        ],
      ),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardPage(),
          const TransactionsPage(),
          const FinancePage(),
          const AccountsListPage(),
        ],
      ),
      floatingActionButton:
          _selectedIndex == 1 ? _buildFloatingActionButton() : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Finans Takip';
      case 1:
        return 'İşlemler';
      case 2:
        return 'Finans Analizi';
      case 3:
        return 'Hesaplar / Kasalar';
      default:
        return 'Finans Takip';
    }
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Özet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz),
          label: 'İşlemler',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Finansal',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Hesaplar',
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () async {
        // İşlem ekleme sayfasına yönlendir
        // ... Kodunuz burada
      },
      child: const Icon(Icons.add),
      tooltip: 'Yeni İşlem Ekle',
    );
  }

  Widget _buildDrawer(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 64,
                ),
                SizedBox(height: 8),
                Text(
                  'Finans Takip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // Tema değiştirme
          SwitchListTile(
            title: const Text('Karanlık Tema'),
            value: isDarkMode,
            secondary: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            onChanged: (value) async {
              widget.onThemeChanged(value);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', value);
            },
          ),
          // Diğer drawer menü öğeleri
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Ayarlar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    onThemeChanged: widget.onThemeChanged,
                    onPrimaryColorChanged: widget.onPrimaryColorChanged,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Tema Rengi'),
            onTap: () {
              Navigator.pop(context);
              _showColorPicker(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Yardım'),
            onTap: () {
              Navigator.pop(context);
              // Yardım sayfasına yönlendir
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Hakkında'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tema Rengi Seçin'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTheme.colorOptions.map((color) {
                return InkWell(
                  onTap: () async {
                    widget.onPrimaryColorChanged(color);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('primaryColor', color.value);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Finans Takip',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.account_balance_wallet,
        size: 48,
      ),
      applicationLegalese: '© 2024 Finance App',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Bu uygulama kişisel finansal takip için geliştirilmiştir.',
        ),
      ],
    );
  }
}
