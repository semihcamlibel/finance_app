import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late NumberFormat currencyFormat =
      NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  String _selectedCurrency = '₺';
  DateTime _selectedDate = DateTime.now();
  Map<TransactionCategory, double> _budgets = {};
  Map<TransactionCategory, double> _expenses = {};
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSettings();
    await _loadBudgetData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
    });
  }

  Future<void> _loadBudgetData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadBudgets();
    await _loadExpenses();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadBudgets() async {
    final budgets =
        await DatabaseHelper.instance.getBudgets(_selectedMonth, _selectedYear);
    setState(() {
      _budgets.clear();
      _budgets.addAll(budgets);
    });
  }

  Future<void> _checkBudgetOverruns() async {
    final overBudgetCategories =
        await DatabaseHelper.instance.getOverBudgetCategories(
      _selectedMonth,
      _selectedYear,
    );

    if (overBudgetCategories.isNotEmpty && mounted) {
      // Bütçe aşımı olan kategoriler için bildirim göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bütçe Aşımı Uyarısı!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...overBudgetCategories.map((item) {
                final category = item['category'] as TransactionCategory;
                final overspend = item['overspend'] as double;
                return Text(
                  '${_getCategoryText(category)}: ${currencyFormat.format(overspend)} aşım',
                  style: const TextStyle(fontSize: 12),
                );
              }),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Tamam',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      // Her kategori için bildirim gönder
      for (var item in overBudgetCategories) {
        final category = item['category'] as TransactionCategory;
        final overspend = item['overspend'] as double;

        await NotificationService.instance.showInstantNotification(
          id: category.index,
          title: 'Bütçe Aşımı: ${_getCategoryText(category)}',
          body:
              '${_getCategoryText(category)} kategorisinde ${currencyFormat.format(overspend)} tutarında bütçe aşımı tespit edildi.',
        );
      }
    }
  }

  Future<void> _loadExpenses() async {
    try {
      print('\n-------------- YENİ BÜTÇE HESAPLAMASI --------------');
      print('Seçili ay/yıl: $_selectedMonth/$_selectedYear');

      // Veritabanından seçili ay ve yıl için tüm işlemleri al
      final transactions = await DatabaseHelper.instance.getTransactionsByDate(
        DateTime(_selectedYear, _selectedMonth),
      );

      // Kategorilere göre harcamaları hesapla
      final Map<TransactionCategory, double> expenses = {};

      print('--------- KATEGORİ BAZLI HARCAMA HESABI ---------');

      // Her kategori için harcamaları sıfırla (tüm kategorileri kapsayacak şekilde)
      for (var category in TransactionCategory.values) {
        expenses[category] = 0.0;
      }

      // Harcamaları topla
      for (var transaction in transactions) {
        // Gider veya ödeme türündeki işlemleri dikkate al
        if (transaction.type == TransactionType.expense ||
            transaction.type == TransactionType.payment) {
          final amount =
              transaction.amount.abs(); // Mutlak değeri kullan (pozitif sayı)
          expenses[transaction.category] =
              (expenses[transaction.category] ?? 0) + amount;

          print(
              '${_getCategoryText(transaction.category)} Kategorisine ${currencyFormat.format(amount)} harcama eklendi, Toplam: ${currencyFormat.format(expenses[transaction.category])}');
        }
      }

      // Debug için harcamaları yazdır
      print('\n----- KATEGORİ HARCAMA ÖZETİ -----');
      TransactionCategory.values.forEach((category) {
        final harcama = expenses[category] ?? 0.0;
        final butce = _budgets[category] ?? 0.0;

        if (harcama > 0 || butce > 0) {
          print(
              '${_getCategoryText(category)}: Bütçe=${currencyFormat.format(butce)}, Harcama=${currencyFormat.format(harcama)}, ${harcama > butce ? "AŞIM VAR" : "Normal"}');
        }
      });

      // State'i güncelle
      setState(() {
        _expenses = expenses;
      });

      // Bütçe aşımlarını kontrol et
      await _checkBudgetOverruns();

      print('-------------- BÜTÇE HESAPLAMASI TAMAMLANDI --------------\n');
    } catch (e) {
      print('Harcamaları yüklerken hata: $e');
    }
  }

  void _showAddBudgetDialog(TransactionCategory category) {
    final controller = TextEditingController(
      text: _budgets[category]?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getCategoryText(category)} için Bütçe Belirle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Bütçe Tutarı',
            prefixText: '₺ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null) {
                await DatabaseHelper.instance.setBudget(
                  category,
                  amount,
                  _selectedMonth,
                  _selectedYear,
                );
                if (mounted) {
                  Navigator.pop(context);
                  await _loadBudgetData(); // Tam veri yenileme
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 24),
                  _buildBudgetSummary(),
                  const SizedBox(height: 24),
                  _buildCategoryBudgets(),
                  const SizedBox(height: 24),
                  _buildBudgetAnalysis(),
                ],
              ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 1) {
                    _selectedMonth = 12;
                    _selectedYear--;
                  } else {
                    _selectedMonth--;
                  }
                });
                _loadBudgetData();
              },
            ),
            Text(
              DateFormat('MMMM yyyy', 'tr_TR')
                  .format(DateTime(_selectedYear, _selectedMonth)),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                  } else {
                    _selectedMonth++;
                  }
                });
                _loadBudgetData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummary() {
    final totalBudget =
        _budgets.values.fold(0.0, (sum, amount) => sum + amount);
    final totalExpense =
        _expenses.values.fold(0.0, (sum, amount) => sum + amount);
    final remainingBudget = totalBudget - totalExpense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bütçe Özeti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Toplam Bütçe', totalBudget, Colors.blue),
            const SizedBox(height: 8),
            _buildSummaryRow('Harcamalar', totalExpense, Colors.red),
            const Divider(),
            _buildSummaryRow('Kalan Bütçe', remainingBudget,
                remainingBudget >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kategori Bütçeleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Bütçe Ekle'),
              onPressed: () => _showCategorySelector(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bütçesi olan kategorileri göster
        ...TransactionCategory.values.map((category) {
          final budget = _budgets[category] ?? 0;
          final expense = _expenses[category] ?? 0;

          // Eğer bu kategoride bütçe veya harcama varsa göster
          if (budget > 0 || expense > 0) {
            return _buildBudgetCard(category);
          }
          return const SizedBox();
        }).toList(),

        // Bütçesi olmayıp harcaması olan kategoriler için bilgi kartı
        if (TransactionCategory.values.any((category) =>
            (_budgets[category] ?? 0) == 0 && (_expenses[category] ?? 0) > 0))
          Card(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Bütçesi Olmayan Harcamalar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aşağıdaki kategorilerde bütçe ayarlanmadığı halde harcama var:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...TransactionCategory.values
                      .where((category) =>
                          (_budgets[category] ?? 0) == 0 &&
                          (_expenses[category] ?? 0) > 0)
                      .map((category) => Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getCategoryText(category)),
                                Text(
                                  currencyFormat
                                      .format(_expenses[category] ?? 0),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Bu kategoriler için bütçe ekleme ekranını göster
                      final firstCategory =
                          TransactionCategory.values.firstWhere(
                        (category) =>
                            (_budgets[category] ?? 0) == 0 &&
                            (_expenses[category] ?? 0) > 0,
                        orElse: () => TransactionCategory.other,
                      );
                      _showAddBudgetDialog(firstCategory);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Bütçe Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBudgetCard(TransactionCategory category) {
    final budget = _budgets[category] ?? 0;
    final expense = _expenses[category] ?? 0;
    final progress = budget > 0 ? (expense / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = expense > budget;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getCategoryText(category),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAddBudgetDialog(category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteBudget(category),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: isOverBudget ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Harcama: ${currencyFormat.format(expense)}',
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.grey[600],
                  ),
                ),
                Text(
                  'Bütçe: ${currencyFormat.format(budget)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (isOverBudget)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bütçe aşımı: ${currencyFormat.format(expense - budget)}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetAnalysis() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bütçe Analizi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Bütçe', Colors.blue.withOpacity(0.7)),
                const SizedBox(width: 24),
                _buildLegendItem(
                    'Normal Harcama', Colors.green.withOpacity(0.8)),
                const SizedBox(width: 24),
                _buildLegendItem('Aşım', Colors.red.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _calculateMaxY(),
                    barGroups: _getBudgetBarGroups(),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final categories =
                                TransactionCategory.values.where((category) {
                              final budget = _budgets[category] ?? 0;
                              final expense = _expenses[category] ?? 0;
                              return budget > 0 || expense > 0;
                            }).toList();

                            if (value >= 0 && value < categories.length) {
                              final category = categories[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: RotatedBox(
                                  quarterTurns: 1,
                                  child: Text(
                                    _getCategoryShortText(category),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                          reservedSize: 48,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                currencyFormat.format(value),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                          interval: _calculateGridInterval(),
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: _calculateGridInterval(),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.15),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                        left: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  double _calculateMaxY() {
    double maxBudget = 0;
    double maxExpense = 0;

    for (var category in TransactionCategory.values) {
      final budget = _budgets[category] ?? 0;
      final expense = _expenses[category] ?? 0;
      maxBudget = budget > maxBudget ? budget : maxBudget;
      maxExpense = expense > maxExpense ? expense : maxExpense;
    }

    final maxValue = maxBudget > maxExpense ? maxBudget : maxExpense;
    // Return at least 1000 as the maximum value if there's no data
    return maxValue > 0 ? maxValue * 1.2 : 1000;
  }

  double _calculateGridInterval() {
    final maxY = _calculateMaxY();
    final desiredIntervals = 5;

    // Handle edge case when maxY is 0 or very small
    if (maxY <= 0) return 200;

    final rawInterval = maxY / desiredIntervals;
    if (rawInterval <= 0) return 200;

    // Sonsuz veya NaN kontrolü
    if (rawInterval.isInfinite || rawInterval.isNaN) return 200;

    // Logaritma hesaplaması için güvenlik kontrolü
    if (rawInterval <= 0) return 200;

    final logValue = log(rawInterval) / ln10;
    if (logValue.isInfinite || logValue.isNaN) return 200;

    final magnitude = pow(10, logValue.floor());
    if (magnitude.isInfinite || magnitude.isNaN) return 200;

    final normalized = rawInterval / magnitude;
    if (normalized.isInfinite || normalized.isNaN) return 200;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = 1;
    } else if (normalized < 3) {
      niceInterval = 2;
    } else if (normalized < 7) {
      niceInterval = 5;
    } else {
      niceInterval = 10;
    }

    final result = niceInterval * magnitude;
    return result.isFinite ? result : 200;
  }

  List<BarChartGroupData> _getBudgetBarGroups() {
    final List<BarChartGroupData> groups = [];
    var index = 0;

    for (var category in TransactionCategory.values) {
      final budget = _budgets[category] ?? 0;
      final expense = _expenses[category] ?? 0;

      if (budget > 0 || expense > 0) {
        groups.add(
          BarChartGroupData(
            x: index,
            groupVertically: true,
            barRods: [
              BarChartRodData(
                toY: budget,
                color: Colors.blue.withOpacity(0.7),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: _calculateMaxY(),
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
              BarChartRodData(
                toY: expense,
                color: expense > budget
                    ? Colors.red.withOpacity(0.8)
                    : Colors.green.withOpacity(0.8),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        );
        index++;
      }
    }

    return groups;
  }

  void _showCategorySelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Seçin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: TransactionCategory.values
                .where((category) => !_budgets.containsKey(category))
                .map((category) => ListTile(
                      title: Text(_getCategoryText(category)),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddBudgetDialog(category);
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );
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

  String _getCategoryShortText(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salary:
        return 'Maaş';
      case TransactionCategory.investment:
        return 'Yat.';
      case TransactionCategory.shopping:
        return 'Alış.';
      case TransactionCategory.bills:
        return 'Fat.';
      case TransactionCategory.food:
        return 'Yem.';
      case TransactionCategory.transport:
        return 'Ulaş.';
      case TransactionCategory.health:
        return 'Sağ.';
      case TransactionCategory.education:
        return 'Eğt.';
      case TransactionCategory.entertainment:
        return 'Eğl.';
      case TransactionCategory.other:
        return 'Diğer';
    }
  }

  Future<void> _deleteBudget(TransactionCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bütçeyi Sil'),
        content: Text(
            '${_getCategoryText(category)} kategorisi için bütçeyi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBudget(
        category,
        _selectedMonth,
        _selectedYear,
      );
      await _loadBudgetData(); // Tam veri yenileme
    }
  }
}
