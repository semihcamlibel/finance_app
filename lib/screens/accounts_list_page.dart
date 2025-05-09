import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/database_helper.dart';
import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import 'account_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountsListPage extends StatefulWidget {
  const AccountsListPage({Key? key}) : super(key: key);

  @override
  _AccountsListPageState createState() => _AccountsListPageState();
}

class _AccountsListPageState extends State<AccountsListPage> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  double _totalBalance = 0;
  String _mainCurrency = '₺'; // Ana para birimi
  Map<String, double> _convertedBalances =
      {}; // Hesap ID'sine göre çevrilmiş bakiyeler

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAccounts();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainCurrency = prefs.getString('currency') ?? '₺';
    });
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await DatabaseHelper.instance.getAllAccounts();

      // Ana para birimine çevrilmiş toplam bakiyeyi hesapla
      double total = 0;
      _convertedBalances = {};

      for (var account in accounts) {
        if (account.isActive) {
          double convertedBalance;

          // Hesap ana para biriminde ise doğrudan ekle
          if (account.currency == _mainCurrency) {
            convertedBalance = account.balance;
          } else {
            // Farklı para biriminde ise çevir
            convertedBalance = ExchangeRateService.instance.convertCurrency(
              account.balance,
              account.currency,
              _mainCurrency,
            );

            // Debug için yazdır
            debugPrint(
              'Hesap ${account.name}: ${account.balance} ${account.currency} = $convertedBalance $_mainCurrency',
            );
          }

          _convertedBalances[account.id] = convertedBalance;
          total += convertedBalance;
        }
      }

      setState(() {
        _accounts = accounts;
        _totalBalance = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesaplar yüklenirken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesaplar / Kasalar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmptyState()
              : _buildAccountsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAccountDetail(null),
        child: const Icon(Icons.add),
        tooltip: 'Yeni Hesap Ekle',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz hesap eklenmemiş.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yeni hesap eklemek için + butonuna tıklayın.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return Column(
      children: [
        // Toplam bakiye özeti kartı
        _buildTotalBalanceCard(),
        // Hesaplar listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _accounts.length,
            itemBuilder: (context, index) {
              final account = _accounts[index];
              return _buildAccountCard(account);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBalanceCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          children: [
            const Text(
              'Toplam Varlık',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DatabaseHelper.getCurrencyFormat(_mainCurrency)
                  .format(_totalBalance),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_accounts.where((a) => a.isActive).length} aktif hesap',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    final convertedBalance = _convertedBalances[account.id] ?? account.balance;
    final showConversion = account.currency != _mainCurrency;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => _navigateToAccountDetail(account),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Hesap ikonu
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(account.colorValue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForAccount(account.iconName),
                  color: Color(account.colorValue),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Hesap detayları
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${account.bankName} (${account.currency})',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Bakiye
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatCurrency(account.balance, account.currency),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (showConversion)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '≈ ${_formatCurrency(convertedBalance, _mainCurrency)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (!account.isActive)
                    const Text(
                      'Pasif',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForAccount(String? iconName) {
    switch (iconName) {
      case 'bank':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      case 'cash':
        return Icons.money;
      case 'savings':
        return Icons.savings;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.account_balance_wallet;
    }
  }

  // Hesap için bakiyeyi ve para birimini formatlayan fonksiyon
  String _formatCurrency(double amount, String currency) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: currency,
      decimalDigits: 2,
    ).format(amount);
  }

  Future<void> _navigateToAccountDetail(Account? account) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountDetailPage(account: account),
      ),
    );

    if (result == true) {
      _loadAccounts();
    }
  }
}
