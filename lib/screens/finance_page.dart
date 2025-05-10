import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/transaction.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({Key? key}) : super(key: key);

  @override
  _FinancePageState createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool _isLoading = true;
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';

  // Date selection
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'month'; // 'month', 'quarter', 'year'

  // Financial data
  List<FinanceTransaction> _transactions = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netWorth = 0;

  // Category data
  Map<TransactionCategory, double> _incomeByCategory = {};
  Map<TransactionCategory, double> _expenseByCategory = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSettings();
    await _loadFinancialData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
    });
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });

    // Get transactions based on selected period
    final DateTime startDate = _getStartDateForPeriod();
    final DateTime endDate = DateTime.now();

    final transactions =
        await DatabaseHelper.instance.getTransactionsByDateRange(
      startDate,
      endDate,
    );

    double totalIncome = 0;
    double totalExpense = 0;
    Map<TransactionCategory, double> incomeByCategory = {};
    Map<TransactionCategory, double> expenseByCategory = {};

    // Process transactions
    for (var transaction in transactions) {
      // For income
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;

        // Add to category breakdown
        final category = transaction.category;
        incomeByCategory[category] =
            (incomeByCategory[category] ?? 0) + transaction.amount;
      }

      // For expense
      else if (transaction.type == TransactionType.expense) {
        totalExpense += transaction.amount.abs(); // Ensure positive value

        // Add to category breakdown
        final category = transaction.category;
        expenseByCategory[category] =
            (expenseByCategory[category] ?? 0) + transaction.amount.abs();
      }
    }

    setState(() {
      _transactions = transactions;
      _totalIncome = totalIncome;
      _totalExpense = totalExpense;
      _netWorth = totalIncome - totalExpense;
      _incomeByCategory = incomeByCategory;
      _expenseByCategory = expenseByCategory;
      _isLoading = false;
    });
  }

  DateTime _getStartDateForPeriod() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'quarter':
        // Start from beginning of current quarter
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        return DateTime(now.year, (currentQuarter - 1) * 3 + 1, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  String _getCategoryText(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salary:
        return 'Maaş';
      case TransactionCategory.investment:
        return 'Yatırım';
      case TransactionCategory.shopping:
        return 'Alışveriş';
      case TransactionCategory.bills:
        return 'Faturalar';
      case TransactionCategory.food:
        return 'Yemek';
      case TransactionCategory.transport:
        return 'Ulaşım';
      case TransactionCategory.health:
        return 'Sağlık';
      case TransactionCategory.education:
        return 'Eğitim';
      case TransactionCategory.entertainment:
        return 'Eğlence';
      case TransactionCategory.other:
        return 'Diğer';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildFinancialSummary(),
            const SizedBox(height: 24),
            _buildTransactionCharts(),
            const SizedBox(height: 24),
            _buildCategoryBreakdown(),
            const SizedBox(height: 24),
            _buildTrends(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finansal Analiz Dönemi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodButton('Bu Ay', 'month'),
                _buildPeriodButton('Bu Çeyrek', 'quarter'),
                _buildPeriodButton('Bu Yıl', 'year'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
        _loadFinancialData();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildFinancialSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finansal Özet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Gelir',
                    _totalIncome,
                    Icons.arrow_upward,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Gider',
                    _totalExpense,
                    Icons.arrow_downward,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(
              'Net Durum',
              _netWorth,
              _netWorth >= 0 ? Icons.trending_up : Icons.trending_down,
              _netWorth >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCharts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gelir ve Gider Dağılımı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.only(right: 16.0, top: 16.0),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _generatePieChartSections(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Gelir', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Gider', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  List<PieChartSectionData> _generatePieChartSections() {
    final sections = <PieChartSectionData>[];

    if (_totalIncome > 0 || _totalExpense > 0) {
      final total = _totalIncome + _totalExpense;

      if (_totalIncome > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.green,
            value: _totalIncome,
            title: '${(_totalIncome / total * 100).toStringAsFixed(0)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }

      if (_totalExpense > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.red,
            value: _totalExpense,
            title: '${(_totalExpense / total * 100).toStringAsFixed(0)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    } else {
      sections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 1,
          title: '0%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildCategoryBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gelir Kategorileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_incomeByCategory.isEmpty)
                  const Text('Bu dönemde gelir işlemi bulunmamaktadır.')
                else
                  ..._incomeByCategory.entries.map((entry) {
                    final percentage = _totalIncome > 0
                        ? (entry.value / _totalIncome * 100)
                        : 0.0;
                    return _buildCategoryItem(
                      _getCategoryText(entry.key),
                      entry.value,
                      percentage,
                      Colors.green,
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gider Kategorileri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_expenseByCategory.isEmpty)
                  const Text('Bu dönemde gider işlemi bulunmamaktadır.')
                else
                  ..._expenseByCategory.entries.map((entry) {
                    final percentage = _totalExpense > 0
                        ? (entry.value / _totalExpense * 100)
                        : 0.0;
                    return _buildCategoryItem(
                      _getCategoryText(entry.key),
                      entry.value,
                      percentage,
                      Colors.red,
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
    String category,
    double amount,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: color.withOpacity(0.1),
                    color: color,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFormat.format(amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finansal Tavsiyeler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAdviceItem(
              Icons.trending_up,
              'Gelir Durumu',
              _getIncomeAdvice(),
              Colors.blue,
            ),
            const Divider(),
            _buildAdviceItem(
              Icons.trending_down,
              'Gider Durumu',
              _getExpenseAdvice(),
              Colors.orange,
            ),
            const Divider(),
            _buildAdviceItem(
              Icons.account_balance_wallet,
              'Genel Tavsiye',
              _getGeneralAdvice(),
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceItem(
    IconData icon,
    String title,
    String message,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getIncomeAdvice() {
    if (_totalIncome <= 0) {
      return 'Bu dönemde gelir kaydedilmemiş. Gelirlerinizi düzenli olarak kaydetmeniz finansal takip için önemlidir.';
    } else if (_incomeByCategory.length <= 1) {
      return 'Gelir kaynaklarınızı çeşitlendirmeniz finansal güvenliğinizi artırabilir.';
    } else {
      return 'Birden fazla gelir kaynağı oluşturarak finansal güvenliğinizi sağlamlaştırmaya devam edin.';
    }
  }

  String _getExpenseAdvice() {
    if (_totalExpense <= 0) {
      return 'Bu dönemde gider kaydedilmemiş. Giderlerinizi düzenli olarak kaydetmeniz finansal takip için önemlidir.';
    } else if (_totalExpense > _totalIncome) {
      return 'Giderleriniz gelirinizden fazla. Bütçenizi gözden geçirerek harcamalarınızı azaltmayı düşünebilirsiniz.';
    } else if (_totalExpense > _totalIncome * 0.9) {
      return 'Giderleriniz gelirinize çok yakın. Daha fazla tasarruf yapmanız önerilir.';
    } else {
      return 'Giderleriniz gelirinizin altında, bu iyi bir bütçe yönetimi göstergesidir.';
    }
  }

  String _getGeneralAdvice() {
    if (_netWorth <= 0) {
      return 'Harcamalarınızı azaltarak veya ek gelir kaynakları oluşturarak finansal durumunuzu iyileştirmeyi hedefleyin.';
    } else if (_netWorth < _totalIncome * 0.2) {
      return 'Tasarruf oranınız düşük. Acil durumlar için bir tasarruf fonu oluşturmayı düşünün.';
    } else {
      return 'İyi bir finansal yönetim sergiliyorsunuz. Yatırım seçeneklerini değerlendirerek birikimlerinizi büyütmeyi düşünebilirsiniz.';
    }
  }
}
