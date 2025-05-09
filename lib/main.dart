import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/transactions_page.dart';
import 'screens/finance_page.dart';
import 'screens/notification_test_page.dart';
import 'screens/accounts_list_page.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

// Yerelleştirme için yardımcı fonksiyon
Future<void> initializeLocalization() async {
  await initializeDateFormatting('tr_TR', null);
}

// Sayfa geçiş animasyonu için özel route sınıfı
class CustomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  CustomPageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirimleri başlat
  await NotificationService.instance.initialize();

  // Uygulamadaki dilleri yükle
  await initializeLocalization();

  // Süresiz tekrarlanan işlemleri kontrol et ve gerekirse yeni işlemler oluştur
  await DatabaseHelper.instance.checkAndCreateFutureRecurringTransactions();

  runApp(const FinanceApp());
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  bool _isDarkMode = false;
  Color _primaryColor = AppTheme.primaryColor;
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.light);
  bool _isAuthenticated = false;
  int _selectedIndex = 0;
  bool _refreshDashboard = false;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final isAuthenticated = await AuthService.instance.authenticate();
    setState(() {
      _isAuthenticated = isAuthenticated;
    });
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _primaryColor =
          Color(prefs.getInt('primaryColor') ?? AppTheme.primaryColor.value);
      _themeMode.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  ThemeData _buildTheme(bool isDark) {
    if (isDark) {
      // Karanlık tema için özel ayarlamalar yapılabilir
      final darkTheme = ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      return darkTheme;
    } else {
      // Aydınlık tema için yeni AppTheme'i kullanalım
      return AppTheme.lightTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.darkGreyColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGreyColor,
          ),
          iconTheme: IconThemeData(
            color: _primaryColor,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Finance App',
          theme: _buildTheme(false),
          darkTheme: _buildTheme(true),
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: (settings) {
            // Tüm sayfalar için animasyonlu geçiş uygula
            return CustomPageRoute(
              child: settings.name == '/'
                  ? (!_isAuthenticated
                      ? _buildAuthenticationScreen()
                      : HomePage(
                          onThemeChanged: (isDark) {
                            setState(() {
                              _isDarkMode = isDark;
                              _themeMode.value =
                                  isDark ? ThemeMode.dark : ThemeMode.light;
                            });
                          },
                          onPrimaryColorChanged: (color) {
                            setState(() {
                              _primaryColor = color;
                            });
                          },
                        ))
                  : Container(),
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'),
          ],
          home: !_isAuthenticated
              ? _buildAuthenticationScreen()
              : HomePage(
                  onThemeChanged: (isDark) {
                    setState(() {
                      _isDarkMode = isDark;
                      _themeMode.value =
                          isDark ? ThemeMode.dark : ThemeMode.light;
                    });
                  },
                  onPrimaryColorChanged: (color) {
                    setState(() {
                      _primaryColor = color;
                    });
                  },
                ),
        );
      },
    );
  }

  Widget _buildAuthenticationScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: _primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Kimlik Doğrulama Gerekli',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Devam etmek için kimlik doğrulama yapın',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final isAuthenticated =
                    await AuthService.instance.authenticate();
                setState(() {
                  _isAuthenticated = isAuthenticated;
                });
              },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Kimlik Doğrula'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildFloatingActionButton() {
    // FloatingActionButton için uygun kod burada eklenebilir
    return FloatingActionButton(
      onPressed: () {
        // FloatingActionButton için işlem eklenecek
      },
      child: const Icon(Icons.add),
    );
  }

  Widget _buildDrawer() {
    // Drawer için uygun kod burada eklenebilir
    return Drawer();
  }
}
