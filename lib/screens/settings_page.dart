import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(Color) onPrimaryColorChanged;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.onPrimaryColorChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notification settings
  bool _showPaymentNotifications = true;
  bool _showIncomeNotifications = true;
  bool _showBudgetNotifications = true;
  int _notificationDaysBefore = 3;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  // Theme settings
  bool _isDarkMode = false;
  Color _primaryColor = Colors.deepPurple;

  // Currency settings
  String _selectedCurrency = '₺';
  final List<String> _availableCurrencies = ['₺', '\$', '€', '£'];

  // Display settings
  bool _showCents = true;
  bool _groupTransactionsByDate = true;
  bool _showTransactionNotes = true;

  // Privacy settings
  bool _requireAuthenticationOnStart = false;
  bool _hideAmounts = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Notification settings
      _showPaymentNotifications =
          prefs.getBool('showPaymentNotifications') ?? true;
      _showIncomeNotifications =
          prefs.getBool('showIncomeNotifications') ?? true;
      _showBudgetNotifications =
          prefs.getBool('showBudgetNotifications') ?? true;
      _notificationDaysBefore = prefs.getInt('notificationDaysBefore') ?? 3;
      _notificationTime = TimeOfDay(
        hour: prefs.getInt('notificationTimeHour') ?? 9,
        minute: prefs.getInt('notificationTimeMinute') ?? 0,
      );

      // Theme settings
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _primaryColor =
          Color(prefs.getInt('primaryColor') ?? Colors.deepPurple.value);

      // Currency settings
      _selectedCurrency = prefs.getString('currency') ?? '₺';

      // Display settings
      _showCents = prefs.getBool('showCents') ?? true;
      _groupTransactionsByDate =
          prefs.getBool('groupTransactionsByDate') ?? true;
      _showTransactionNotes = prefs.getBool('showTransactionNotes') ?? true;

      // Privacy settings
      _requireAuthenticationOnStart =
          prefs.getBool('requireAuthenticationOnStart') ?? false;
      _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Notification settings
    await prefs.setBool('showPaymentNotifications', _showPaymentNotifications);
    await prefs.setBool('showIncomeNotifications', _showIncomeNotifications);
    await prefs.setBool('showBudgetNotifications', _showBudgetNotifications);
    await prefs.setInt('notificationDaysBefore', _notificationDaysBefore);
    await prefs.setInt('notificationTimeHour', _notificationTime.hour);
    await prefs.setInt('notificationTimeMinute', _notificationTime.minute);

    // Theme settings
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setInt('primaryColor', _primaryColor.value);

    // Currency settings
    await prefs.setString('currency', _selectedCurrency);

    // Display settings
    await prefs.setBool('showCents', _showCents);
    await prefs.setBool('groupTransactionsByDate', _groupTransactionsByDate);
    await prefs.setBool('showTransactionNotes', _showTransactionNotes);

    // Privacy settings
    await prefs.setBool(
        'requireAuthenticationOnStart', _requireAuthenticationOnStart);
    await prefs.setBool('hideAmounts', _hideAmounts);

    // Notify parent widgets about theme changes
    widget.onThemeChanged(_isDarkMode);
    widget.onPrimaryColorChanged(_primaryColor);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ayarlar kaydedildi'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
      });
      await _saveSettings();
    }
  }

  Future<void> _selectPrimaryColor() async {
    final Color? picked = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ana Renk Seçin'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppTheme.colorOptions.map((color) {
                return InkWell(
                  onTap: () => Navigator.of(context).pop(color),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryColor == color
                            ? Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _primaryColor == color
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _primaryColor) {
      setState(() {
        _primaryColor = picked;
      });
      await _saveSettings();
    }
  }

  Future<void> _onCurrencyChanged(String? value) async {
    if (value != null) {
      setState(() => _selectedCurrency = value);
      await _saveSettings();
      // Yeniden yükleme için ana sayfaya bildir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Para birimi güncellendi'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              onThemeChanged: widget.onThemeChanged,
              onPrimaryColorChanged: widget.onPrimaryColorChanged,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSection(
            'Bildirim Ayarları',
            Icons.notifications_outlined,
            [
              SwitchListTile.adaptive(
                title: const Text('Ödeme Bildirimleri'),
                subtitle: const Text('Yaklaşan ödemeler için bildirim al'),
                value: _showPaymentNotifications,
                onChanged: (value) async {
                  setState(() => _showPaymentNotifications = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              SwitchListTile.adaptive(
                title: const Text('Gelir Bildirimleri'),
                subtitle: const Text('Beklenen gelirler için bildirim al'),
                value: _showIncomeNotifications,
                onChanged: (value) async {
                  setState(() => _showIncomeNotifications = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              SwitchListTile.adaptive(
                title: const Text('Bütçe Bildirimleri'),
                subtitle: const Text('Bütçe aşımları için bildirim al'),
                value: _showBudgetNotifications,
                onChanged: (value) async {
                  setState(() => _showBudgetNotifications = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              ListTile(
                title: const Text('Bildirim Zamanı'),
                subtitle: Text('Her gün ${_notificationTime.format(context)}'),
                trailing: Icon(Icons.access_time, color: _primaryColor),
                onTap: _selectNotificationTime,
              ),
              ListTile(
                title: const Text('Bildirim Gün Sayısı'),
                subtitle: Text('$_notificationDaysBefore gün önceden bildir'),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () async {
                          if (_notificationDaysBefore > 1) {
                            setState(() => _notificationDaysBefore--);
                            await _saveSettings();
                          }
                        },
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_notificationDaysBefore',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          setState(() => _notificationDaysBefore++);
                          await _saveSettings();
                        },
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            'Görünüm Ayarları',
            Icons.palette_outlined,
            [
              SwitchListTile.adaptive(
                title: const Text('Karanlık Tema'),
                subtitle: const Text('Karanlık temayı kullan'),
                value: _isDarkMode,
                onChanged: (value) async {
                  setState(() => _isDarkMode = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              ListTile(
                title: const Text('Ana Renk'),
                subtitle: const Text('Uygulamanın ana rengini değiştir'),
                trailing: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                onTap: _selectPrimaryColor,
              ),
            ],
          ),
          _buildSection(
            'Para Birimi ve Gösterim',
            Icons.currency_exchange,
            [
              ListTile(
                title: const Text('Para Birimi'),
                subtitle: Text('Seçili: $_selectedCurrency'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      onChanged: _onCurrencyChanged,
                      items: _availableCurrencies.map((String currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(
                            currency,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SwitchListTile.adaptive(
                title: const Text('Kuruş Göster'),
                subtitle: const Text('Tutarlarda kuruşları göster'),
                value: _showCents,
                onChanged: (value) async {
                  setState(() => _showCents = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
            ],
          ),
          _buildSection(
            'Liste Görünümü',
            Icons.list_alt,
            [
              SwitchListTile.adaptive(
                title: const Text('Tarihe Göre Grupla'),
                subtitle: const Text('İşlemleri tarihlerine göre grupla'),
                value: _groupTransactionsByDate,
                onChanged: (value) async {
                  setState(() => _groupTransactionsByDate = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              SwitchListTile.adaptive(
                title: const Text('Notları Göster'),
                subtitle: const Text('İşlem notlarını listede göster'),
                value: _showTransactionNotes,
                onChanged: (value) async {
                  setState(() => _showTransactionNotes = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
            ],
          ),
          _buildSection(
            'Gizlilik',
            Icons.security,
            [
              SwitchListTile.adaptive(
                title: const Text('Başlangıçta Kimlik Doğrulama'),
                subtitle:
                    const Text('Uygulama açılışında kimlik doğrulama iste'),
                value: _requireAuthenticationOnStart,
                onChanged: (value) async {
                  setState(() => _requireAuthenticationOnStart = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
              SwitchListTile.adaptive(
                title: const Text('Tutarları Gizle'),
                subtitle: const Text('Tüm tutarları "*****" olarak göster'),
                value: _hideAmounts,
                onChanged: (value) async {
                  setState(() => _hideAmounts = value);
                  await _saveSettings();
                },
                activeColor: _primaryColor,
              ),
            ],
          ),
          _buildSection(
            'Hakkında',
            Icons.info_outline,
            [
              ListTile(
                title: const Text('Uygulama Versiyonu'),
                subtitle: const Text('1.0.0'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Beta',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              ListTile(
                title: const Text('Bildirimleri Sıfırla'),
                subtitle:
                    const Text('Tüm bildirimleri temizle ve yeniden planla'),
                trailing: Icon(Icons.refresh, color: _primaryColor),
                onTap: () async {
                  await NotificationService.instance.cancelAllNotifications();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Bildirimler sıfırlandı'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData iconData, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(iconData, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
