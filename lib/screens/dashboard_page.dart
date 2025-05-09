import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'notifications_list_page.dart';
import '../services/currency_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';
  bool _hideAmounts = false;
  int _notificationCount = 0;
  bool _isLoadingCurrencies = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Kurları başlangıçta yükle
    setState(() => _isLoadingCurrencies = true);
    await CurrencyService.instance.initializeRates();

    await _loadSettings();
    await _loadNotificationCount();

    setState(() => _isLoadingCurrencies = false);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
      _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    });
  }

  Future<void> _loadNotificationCount() async {
    // Bekleyen ödemeleri al
    final upcomingPayments = await _getUpcomingPaymentCount();

    // Gecikmiş ödemeleri al
    final overduePayments = await _getOverduePaymentCount();

    // Bütçe aşımı bildirimlerini al
    final budgetAlerts = await _getBudgetAlertCount();

    setState(() {
      _notificationCount = upcomingPayments + overduePayments + budgetAlerts;
    });
  }

  Future<int> _getUpcomingPaymentCount() async {
    final unpaidExpenses = await DatabaseHelper.instance.getUnpaidExpenses();
    final now = DateTime.now();

    return unpaidExpenses
        .where((transaction) =>
            transaction.date.isAfter(now) &&
            transaction.date.difference(now).inDays <= 7)
        .length;
  }

  Future<int> _getOverduePaymentCount() async {
    final unpaidExpenses = await DatabaseHelper.instance.getUnpaidExpenses();
    final now = DateTime.now();

    return unpaidExpenses
        .where((transaction) => transaction.date.isBefore(now))
        .length;
  }

  Future<int> _getBudgetAlertCount() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final overBudgetCategories = await DatabaseHelper.instance
        .getOverBudgetCategories(currentMonth, currentYear);

    return overBudgetCategories.length;
  }

  // Bildirim sayısını yeniden yükle
  void refreshNotifications() {
    _loadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            _buildFinancialSummary(),
            _buildOverdueAndUpcomingPayments(),
            _buildCharts(),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finansal Durum',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGreyColor,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now()),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.greyColor,
                        ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsListPage(),
                    ),
                  ).then((result) {
                    // Bildirimler sayfasından dönünce sayımı güncelle
                    // result == true ise bildirimler okundu demektir
                    if (result == true) {
                      // Bildirimleri tamamen yeniden yükle
                      _loadNotificationCount();
                    }
                  });
                },
                child: Stack(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_none_outlined,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _notificationCount > 9
                                ? '9+'
                                : _notificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return FutureBuilder<Map<String, double>>(
      future: _getFinancialSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isLoadingCurrencies) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        // Net değeri ve hesap bakiyelerini de içeren toplam varlık
        final netWorth = data['netWorth']!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildMainBalanceCard(netWorth, data['accountsTotal'] ?? 0),
              const SizedBox(height: 24),
              Text(
                'Genel Bakış',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSummaryGrid(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryGrid(Map<String, double> data) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          'Gelir',
          data['income']!,
          Icons.arrow_upward_rounded,
          AppTheme.incomeColor,
        ),
        _buildSummaryCard(
          'Gider',
          data['expense']!,
          Icons.arrow_downward_rounded,
          AppTheme.expenseColor,
        ),
        _buildSummaryCard(
          'Alacak',
          data['credit']!,
          Icons.account_balance_wallet_rounded,
          AppTheme.accentColor,
        ),
        _buildSummaryCard(
          'Borç',
          data['debt']!,
          Icons.money_off_rounded,
          AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 24,
                  width: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      amount > 0
                          ? '+${amount.toStringAsFixed(0)}%'
                          : '${amount.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppTheme.greyColor,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _hideAmounts ? '*****' : currencyFormat.format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBalanceCard(double balance, double accountsTotal) {
    final isPositive = balance >= 0;
    final color = isPositive ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Toplam Varlık',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '6.4%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _hideAmounts ? '*****' : currencyFormat.format(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 5),
            // Hesaplarda bulunan toplam miktar
            if (accountsTotal > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _hideAmounts
                      ? '****'
                      : 'Hesaplarda: ${currencyFormat.format(accountsTotal)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bu ayki toplam varlık değişimi',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueAndUpcomingPayments() {
    return FutureBuilder<List<FinanceTransaction>>(
      future: DatabaseHelper.instance.getUnpaidExpenses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox();

        final overdueTransactions = snapshot.data!
            .where((t) => !t.isPaid && t.date.isBefore(DateTime.now()))
            .toList();

        if (overdueTransactions.isEmpty) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.errorColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gecikmiş Ödemeler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: overdueTransactions.length > 3
                    ? 3
                    : overdueTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = overdueTransactions[index];
                  final daysOverdue =
                      DateTime.now().difference(transaction.date).inDays;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                '$daysOverdue gün gecikmiş',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _hideAmounts
                                ? '****'
                                : currencyFormat.format(transaction.amount),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.errorColor,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (overdueTransactions.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // Navigate to transactions page
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('Tümünü Gör'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son 7 Gün',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildChartLegendItem('Gelir', AppTheme.incomeColor),
                    _buildChartLegendItem('Gider', AppTheme.expenseColor),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: FutureBuilder<List<FinanceTransaction>>(
                    future:
                        DatabaseHelper.instance.getTransactionsForLastDays(7),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return _buildBarChart(snapshot.data!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son İşlemler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to transactions page
                },
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<FinanceTransaction>>(
            future: DatabaseHelper.instance.getRecentTransactions(5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: AppTheme.greyColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz işlem kaydı bulunmuyor',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.greyColor,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final transaction = snapshot.data![index];
                  return _buildTransactionItem(transaction);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(FinanceTransaction transaction) {
    final isIncome = transaction.amount >= 0;
    final color = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final icon = isIncome ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  DateFormat('dd MMMM yyyy', 'tr_TR').format(transaction.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _hideAmounts ? '****' : currencyFormat.format(transaction.amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<FinanceTransaction> transactions) {
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DateFormat('E', 'tr_TR').format(day).substring(0, 2);
    });

    // Günlük gelir ve gider toplamlarını hesapla
    final Map<int, double> incomeData = {};
    final Map<int, double> expenseData = {};

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final dayTransactions = transactions.where((t) =>
          t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day);

      double income = 0;
      double expense = 0;

      for (var transaction in dayTransactions) {
        if (transaction.amount >= 0) {
          income += transaction.amount;
        } else {
          expense += transaction.amount.abs();
        }
      }

      incomeData[i] = income;
      expenseData[i] = expense;
    }

    // Max değeri bulma
    double maxValue = 0;
    for (int i = 0; i < 7; i++) {
      final total = (incomeData[i] ?? 0) + (expenseData[i] ?? 0);
      if (total > maxValue) maxValue = total;
    }

    // Eğer tüm değerler 0 ise, minimum bir yükseklik için
    maxValue = maxValue == 0 ? 1000 : maxValue;

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2, // Biraz ekstra alan bırakma
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: incomeData[i] ?? 0,
                color: AppTheme.incomeColor,
                width: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: expenseData[i] ?? 0,
                color: AppTheme.expenseColor,
                width: 8,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    dayLabels[value.toInt()],
                    style: const TextStyle(
                      color: AppTheme.greyColor,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade800,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              return BarTooltipItem(
                _hideAmounts ? '***' : currencyFormat.format(value),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Map<String, double>> _getFinancialSummary() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    final accounts = await DatabaseHelper.instance.getAllAccounts();

    double income = 0;
    double expense = 0;
    double credit = await DatabaseHelper.instance.getTotalCredit();
    double debt = await DatabaseHelper.instance.getTotalDebt();
    double accountsTotal = 0;

    // Varlık hesaplama mantığı
    for (var transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense ||
          transaction.type == TransactionType.payment) {
        if (transaction.isPaid) {
          // Sadece ödenmiş giderleri dahil et
          expense += transaction.amount.abs();
        }
      }
    }

    // Hesapları kullanıcının seçtiği para birimine çevir ve topla
    if (accounts.isNotEmpty) {
      for (var account in accounts) {
        if (account.isActive) {
          // Hesap bakiyesini kullanıcının seçtiği para birimine çevir
          double convertedBalance = CurrencyService.instance
              .convertAccountBalance(
                  account.balance, account.currency, _selectedCurrency);
          accountsTotal += convertedBalance;
        }
      }
    }

    // Net toplam varlık: İşlemlerden gelen net değer + hesaplardaki toplam bakiye
    double netWorth = (income - expense + credit - debt + accountsTotal);

    return {
      'income': income,
      'expense': expense,
      'credit': credit,
      'debt': debt,
      'accountsTotal': accountsTotal,
      'netWorth': netWorth,
    };
  }
}
