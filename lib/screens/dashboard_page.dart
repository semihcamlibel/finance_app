import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';
import '../models/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';
  bool _hideAmounts = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
      _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildFinancialSummary(),
          _buildOverdueAndUpcomingPayments(),
          _buildCharts(),
          _buildRecentTransactions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Finansal Özet',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return FutureBuilder<Map<String, double>>(
      future: _getFinancialSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final netWorth = (data['income']! -
            data['expense']! +
            data['credit']! -
            data['debt']!);

        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryCard(
                'Net Durum',
                netWorth,
                netWorth >= 0 ? Colors.green : Colors.red,
                Icons.account_balance,
                isLarge: true,
              ),
              const SizedBox(height: 16),
              if (data['income']! > 0 || data['expense']! > 0)
                Row(
                  children: [
                    if (data['income']! > 0)
                      Expanded(
                        child: _buildSummaryCard(
                          'Gelir',
                          data['income']!,
                          Colors.green,
                          Icons.arrow_upward,
                        ),
                      ),
                    if (data['income']! > 0 && data['expense']! > 0)
                      const SizedBox(width: 16),
                    if (data['expense']! > 0)
                      Expanded(
                        child: _buildSummaryCard(
                          'Gider',
                          data['expense']!,
                          Colors.red,
                          Icons.arrow_downward,
                        ),
                      ),
                  ],
                ),
              if ((data['income']! > 0 || data['expense']! > 0) &&
                  (data['credit']! > 0 || data['debt']! > 0))
                const SizedBox(height: 16),
              if (data['credit']! > 0 || data['debt']! > 0)
                Row(
                  children: [
                    if (data['credit']! > 0)
                      Expanded(
                        child: _buildSummaryCard(
                          'Alacak',
                          data['credit']!,
                          Colors.blue,
                          Icons.attach_money,
                        ),
                      ),
                    if (data['credit']! > 0 && data['debt']! > 0)
                      const SizedBox(width: 16),
                    if (data['debt']! > 0)
                      Expanded(
                        child: _buildSummaryCard(
                          'Borç',
                          data['debt']!,
                          Colors.orange,
                          Icons.money_off,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverdueAndUpcomingPayments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<FinanceTransaction>>(
          future: DatabaseHelper.instance.getUnpaidExpenses(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final overdueTransactions = snapshot.data!
                .where((t) => !t.isPaid && t.date.isBefore(DateTime.now()))
                .toList();

            if (overdueTransactions.isEmpty) return const SizedBox();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Gecikmiş Ödemeler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: overdueTransactions.map((transaction) {
                      final daysOverdue =
                          DateTime.now().difference(transaction.date).inDays;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(
                            transaction.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${DateFormat('dd.MM.yyyy').format(transaction.date)} ($daysOverdue gün gecikmiş)',
                            style: const TextStyle(color: Colors.red),
                          ),
                          trailing: Text(
                            currencyFormat.format(transaction.amount),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
        FutureBuilder<List<FinanceTransaction>>(
          future: DatabaseHelper.instance.getUnpaidExpenses(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final now = DateTime.now();
            final threeDaysLater = now.add(const Duration(days: 3));

            final upcomingTransactions = snapshot.data!
                .where((t) =>
                    !t.isPaid &&
                    t.date.isAfter(now) &&
                    t.date.isBefore(threeDaysLater))
                .toList();

            if (upcomingTransactions.isEmpty) return const SizedBox();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.upcoming, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Yaklaşan Ödemeler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: upcomingTransactions.map((transaction) {
                      final daysLeft =
                          transaction.date.difference(DateTime.now()).inDays;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading:
                              const Icon(Icons.upcoming, color: Colors.orange),
                          title: Text(
                            transaction.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${DateFormat('dd.MM.yyyy').format(transaction.date)} ($daysLeft gün kaldı)',
                            style: const TextStyle(color: Colors.orange),
                          ),
                          trailing: Text(
                            currencyFormat.format(transaction.amount),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCharts() {
    return FutureBuilder<Map<String, double>>(
      future: _getFinancialSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!;
        final hasIncomeOrExpense = data['income']! > 0 || data['expense']! > 0;
        final hasCreditOrDebt = data['credit']! > 0 || data['debt']! > 0;

        return Column(
          children: [
            if (hasIncomeOrExpense) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gelir/Gider Dağılımı',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                if (data['income']! > 0)
                                  PieChartSectionData(
                                    value: data['income']!,
                                    title: 'Gelir',
                                    color: Colors.green,
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (data['expense']! > 0)
                                  PieChartSectionData(
                                    value: data['expense']!,
                                    title: 'Gider',
                                    color: Colors.red,
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (hasCreditOrDebt) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alacak/Borç Dağılımı',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                if (data['credit']! > 0)
                                  PieChartSectionData(
                                    value: data['credit']!,
                                    title: 'Alacak',
                                    color: Colors.blue,
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                if (data['debt']! > 0)
                                  PieChartSectionData(
                                    value: data['debt']!,
                                    title: 'Borç',
                                    color: Colors.orange,
                                    radius: 80,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Son İşlemler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<FinanceTransaction>>(
                future: DatabaseHelper.instance.getAllTransactions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Hata: ${snapshot.error}'));
                  }

                  final transactions = snapshot.data!;
                  transactions.sort((a, b) => b.date.compareTo(a.date));
                  final recentTransactions = transactions.take(5).toList();

                  if (recentTransactions.isEmpty) {
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Henüz işlem bulunmuyor',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: recentTransactions.map((transaction) {
                        return Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getAmountColor(transaction.type)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _getTransactionIcon(transaction.type),
                              ),
                              title: Text(
                                transaction.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd.MM.yyyy')
                                        .format(transaction.date),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (transaction.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      transaction.description!,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: _hideAmounts
                                  ? const Text(
                                      '*****',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : Text(
                                      currencyFormat.format(transaction.amount),
                                      style: TextStyle(
                                        color:
                                            _getAmountColor(transaction.type),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                            if (recentTransactions.last != transaction)
                              const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon,
      {bool isLarge = false}) {
    if (amount == 0) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final textColor =
        isDark ? Theme.of(context).colorScheme.onSurface : Colors.black87;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(isLarge ? 24.0 : 16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardColor,
              isDark
                  ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                  : color.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isLarge ? 20 : 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _hideAmounts
                ? Text(
                    '*****',
                    style: TextStyle(
                      fontSize: isLarge ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  )
                : Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontSize: isLarge ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> _getFinancialSummary() async {
    final income = await DatabaseHelper.instance.getTotalIncome();
    final expense = await DatabaseHelper.instance.getTotalExpense();
    final debt = await DatabaseHelper.instance.getTotalDebt();
    final credit = await DatabaseHelper.instance.getTotalCredit();

    return {
      'income': income,
      'expense': expense,
      'debt': debt,
      'credit': credit,
    };
  }

  Icon _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return const Icon(Icons.arrow_upward, color: Colors.green);
      case TransactionType.expense:
        return const Icon(Icons.arrow_downward, color: Colors.red);
      case TransactionType.debt:
        return const Icon(Icons.money_off, color: Colors.orange);
      case TransactionType.credit:
        return const Icon(Icons.attach_money, color: Colors.blue);
      case TransactionType.payment:
        return const Icon(Icons.payment, color: Colors.purple);
    }
  }

  Color _getAmountColor(TransactionType type) {
    switch (type) {
      case TransactionType.income:
      case TransactionType.credit:
        return Colors.green;
      case TransactionType.expense:
      case TransactionType.debt:
        return Colors.red;
      case TransactionType.payment:
        return Colors.purple;
    }
  }
}
