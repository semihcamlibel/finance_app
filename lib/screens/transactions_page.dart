import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'add_transaction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';
  TransactionType? _selectedType;
  List<FinanceTransaction> _allTransactions = [];
  List<FinanceTransaction> _filteredTransactions = [];
  bool _isLoading = true;
  bool _hideAmounts = false;
  bool _showTransactionNotes = true;
  bool _groupTransactionsByDate = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadTransactions();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
      _hideAmounts = prefs.getBool('hideAmounts') ?? false;
      _showTransactionNotes = prefs.getBool('showTransactionNotes') ?? true;
      _groupTransactionsByDate =
          prefs.getBool('groupTransactionsByDate') ?? true;
    });
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      _allTransactions = await DatabaseHelper.instance.getAllTransactions();
      _allTransactions.sort((a, b) => b.date.compareTo(a.date));
      _filterTransactions();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterTransactions() {
    setState(() {
      if (_selectedType == null) {
        _filteredTransactions = _groupRecurringTransactions(_allTransactions);
      } else {
        _filteredTransactions = _groupRecurringTransactions(
          _allTransactions.where((t) => t.type == _selectedType).toList(),
        );
      }
      _filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  List<FinanceTransaction> _groupRecurringTransactions(
      List<FinanceTransaction> transactions) {
    final Map<String?, List<FinanceTransaction>> groups = {};
    final List<FinanceTransaction> result = [];

    // Tekrarlayan işlemleri grupla
    for (var transaction in transactions) {
      if (transaction.parentTransactionId != null) {
        final parentId = transaction.parentTransactionId;
        groups[parentId] = groups[parentId] ?? [];
        groups[parentId]!.add(transaction);
      } else if (transaction.recurringType != RecurringType.none) {
        final parentId = transaction.id;
        groups[parentId] = groups[parentId] ?? [];
        groups[parentId]!.add(transaction);
      } else {
        result.add(transaction);
      }
    }

    // Ana işlemleri ekle
    for (var transaction in transactions) {
      if (transaction.parentTransactionId == null &&
          transaction.recurringType != RecurringType.none &&
          groups.containsKey(transaction.id)) {
        result.add(transaction);
      }
    }

    return result;
  }

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('İşlemi Sil'),
          content: Text(
              '${transaction.title} işlemini silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await DatabaseHelper.instance.deleteTransaction(transaction.id);
      _loadTransactions();
    }
  }

  Future<void> _editTransaction(FinanceTransaction transaction) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddTransactionPage(transaction: transaction),
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
      ),
    );
    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İşlemler',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tümü'),
                  selected: _selectedType == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = null;
                      _filterTransactions();
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...TransactionType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_getTransactionTypeText(type)),
                      selected: _selectedType == type,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? type : null;
                          _filterTransactions();
                        });
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? const Center(child: Text('İşlem bulunamadı'))
                    : _groupTransactionsByDate
                        ? _buildGroupedTransactionsList()
                        : ListView.builder(
                            itemCount: _filteredTransactions.length,
                            itemBuilder: (context, index) {
                              return _buildTransactionCard(
                                  _filteredTransactions[index]);
                            },
                          ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );
                if (result == true) {
                  _loadTransactions();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Yeni İşlem'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactionsList() {
    // İşlemleri tarihe göre grupla
    final Map<String, List<FinanceTransaction>> groupedTransactions = {};
    for (var transaction in _filteredTransactions) {
      final dateKey =
          DateFormat('dd MMMM yyyy', 'tr_TR').format(transaction.date);
      groupedTransactions[dateKey] = groupedTransactions[dateKey] ?? [];
      groupedTransactions[dateKey]!.add(transaction);
    }

    return ListView.builder(
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateKey = groupedTransactions.keys.elementAt(index);
        final transactions = groupedTransactions[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...transactions
                .map((transaction) => _buildTransactionCard(transaction)),
          ],
        );
      },
    );
  }

  String _getTransactionTypeText(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Gelir';
      case TransactionType.expense:
        return 'Gider';
      case TransactionType.debt:
        return 'Borç';
      case TransactionType.credit:
        return 'Alacak';
      case TransactionType.payment:
        return 'Ödeme';
    }
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

  Widget _buildTransactionCard(FinanceTransaction transaction) {
    return Card(
      child: Hero(
        tag: 'transaction_${transaction.id}',
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _getTransactionIcon(transaction.type),
                title: Row(
                  children: [
                    Expanded(child: Text(transaction.title)),
                    if (transaction.recurringType != RecurringType.none)
                      Tooltip(
                        message:
                            _getRecurringTypeText(transaction.recurringType),
                        child: const Icon(Icons.repeat, size: 16),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('dd.MM.yyyy').format(transaction.date)),
                    if (_showTransactionNotes &&
                        transaction.description != null)
                      Text(
                        transaction.description!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    if (transaction.recurringType != RecurringType.none)
                      FutureBuilder<List<FinanceTransaction>>(
                        future: DatabaseHelper.instance
                            .getRecurringTransactions(transaction.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final recurringTransactions = snapshot.data!;
                          final totalCount = recurringTransactions.length;
                          final completedCount = recurringTransactions
                              .where((t) => t.isPaid || t.isReceived)
                              .length;
                          return Text(
                            'Tekrar: $completedCount/$totalCount',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    if (transaction.type == TransactionType.credit)
                      _buildCreditStatus(transaction),
                    if (transaction.type == TransactionType.payment ||
                        transaction.type == TransactionType.expense ||
                        transaction.type == TransactionType.income)
                      _buildPaymentStatus(transaction),
                  ],
                ),
                trailing: _hideAmounts
                    ? const Text('*****',
                        style: TextStyle(fontWeight: FontWeight.bold))
                    : Text(
                        currencyFormat.format(transaction.amount),
                        style: TextStyle(
                          color: _getAmountColor(transaction.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                onTap: () {
                  if (transaction.type == TransactionType.credit) {
                    _showCreditActionDialog(transaction);
                  } else if (transaction.type == TransactionType.payment ||
                      transaction.type == TransactionType.expense ||
                      transaction.type == TransactionType.income) {
                    _showPaymentActionDialog(transaction);
                  }
                },
              ),
              ButtonBar(
                children: [
                  if (transaction.recurringType != RecurringType.none)
                    TextButton.icon(
                      icon: const Icon(Icons.list),
                      label: const Text('Tüm Tekrarlar'),
                      onPressed: () =>
                          _showRecurringTransactionsDialog(transaction),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Düzenle'),
                    onPressed: () => _editTransaction(transaction),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Sil'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => _deleteTransaction(transaction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecurringTransactionsDialog(
      FinanceTransaction parentTransaction) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${parentTransaction.title} - Tekrarlar'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<FinanceTransaction>>(
              future: DatabaseHelper.instance
                  .getRecurringTransactions(parentTransaction.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isOverdue = transaction.date.isBefore(DateTime.now());

                    return ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('dd.MM.yyyy').format(transaction.date),
                              style: TextStyle(
                                color: isOverdue ? Colors.red : null,
                              ),
                            ),
                          ),
                          Text(
                            currencyFormat.format(transaction.amount),
                            style: TextStyle(
                              color: _getAmountColor(transaction.type),
                            ),
                          ),
                        ],
                      ),
                      subtitle: _buildTransactionStatus(transaction),
                      trailing: IconButton(
                        icon: Icon(
                          transaction.isPaid || transaction.isReceived
                              ? Icons.check_circle
                              : Icons.pending,
                          color: transaction.isPaid || transaction.isReceived
                              ? Colors.green
                              : Colors.orange,
                        ),
                        onPressed: () async {
                          if (transaction.type == TransactionType.income) {
                            if (transaction.isPaid) {
                              await DatabaseHelper.instance
                                  .markPaymentAsUnpaid(transaction.id);
                            } else {
                              await DatabaseHelper.instance
                                  .markPaymentAsPaid(transaction.id);
                            }
                          } else if (transaction.type ==
                                  TransactionType.expense ||
                              transaction.type == TransactionType.payment) {
                            if (transaction.isPaid) {
                              await DatabaseHelper.instance
                                  .markPaymentAsUnpaid(transaction.id);
                            } else {
                              await DatabaseHelper.instance
                                  .markPaymentAsPaid(transaction.id);
                            }
                          }
                          Navigator.of(context).pop();
                          _showRecurringTransactionsDialog(parentTransaction);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadTransactions();
              },
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionStatus(FinanceTransaction transaction) {
    if (transaction.isPaid || transaction.isReceived) {
      final statusDate = transaction.paidDate ?? transaction.receivedDate;
      return Text(
        transaction.type == TransactionType.income
            ? 'Alındı: ${DateFormat('dd.MM.yyyy').format(statusDate!)}'
            : 'Ödendi: ${DateFormat('dd.MM.yyyy').format(statusDate!)}',
        style: const TextStyle(color: Colors.green, fontSize: 12),
      );
    } else {
      final isOverdue = transaction.date.isBefore(DateTime.now());
      return Text(
        transaction.type == TransactionType.income
            ? (isOverdue ? 'Gecikmiş Gelir' : 'Alınmadı')
            : (isOverdue ? 'Gecikmiş Ödeme' : 'Ödenmedi'),
        style: TextStyle(
          color: isOverdue ? Colors.red : Colors.orange,
          fontSize: 12,
        ),
      );
    }
  }

  String _getRecurringTypeText(RecurringType type) {
    switch (type) {
      case RecurringType.none:
        return 'Tekrar Etmeyen';
      case RecurringType.monthly:
        return 'Aylık';
      case RecurringType.yearly:
        return 'Yıllık';
    }
  }

  Widget _buildCreditStatus(FinanceTransaction transaction) {
    if (transaction.isReceived) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            'Tahsil edildi: ${DateFormat('dd.MM.yyyy').format(transaction.receivedDate!)}',
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.pending, color: Colors.orange, size: 16),
          const SizedBox(width: 4),
          const Text(
            'Beklemede',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      );
    }
  }

  Widget _buildPaymentStatus(FinanceTransaction transaction) {
    if (transaction.isPaid) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            'Ödendi: ${DateFormat('dd.MM.yyyy').format(transaction.paidDate!)}',
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      );
    } else {
      final isOverdue = transaction.date.isBefore(DateTime.now());
      return Row(
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.pending,
            color: isOverdue ? Colors.red : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isOverdue ? 'Gecikmiş Ödeme' : 'Ödeme Bekliyor',
            style: TextStyle(
              color: isOverdue ? Colors.red : Colors.orange,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
  }

  Future<void> _showCreditActionDialog(FinanceTransaction transaction) async {
    // Tekrarlayan işlem mi kontrol et
    bool isRecurring = transaction.recurringType != RecurringType.none ||
        transaction.parentTransactionId != null;

    bool applyToAll = false;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Alacak Durumu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.isReceived
                    ? '${transaction.title} alacağını tahsil edilmedi olarak işaretlemek istiyor musunuz?'
                    : '${transaction.title} alacağı tahsil edildi mi?'),
                if (isRecurring) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: applyToAll,
                        onChanged: (value) {
                          setState(() {
                            applyToAll = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Önceki tekrarlanan işlemlere de uygula',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu seçenek, bu işlem tarihinden önceki tüm tekrarlanan işlemleri aynı şekilde işaretleyecektir.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(transaction.isReceived
                    ? 'Tahsil Edilmedi'
                    : 'Tahsil Edildi'),
              ),
            ],
          );
        });
      },
    );

    if (result == true) {
      if (transaction.isReceived) {
        await DatabaseHelper.instance.markCreditAsNotReceived(transaction.id);
      } else {
        await DatabaseHelper.instance.markCreditAsReceived(transaction.id);
      }

      // Eğer "tümüne uygula" seçeneği işaretlendiyse tekrarlanan işlemleri güncelle
      if (applyToAll && isRecurring) {
        await DatabaseHelper.instance.updateRecurringTransactionStatus(
            transaction.id, !transaction.isReceived);
      }

      _loadTransactions();
    }
  }

  Future<void> _showPaymentActionDialog(FinanceTransaction transaction) async {
    // Tekrarlayan işlem mi kontrol et
    bool isRecurring = transaction.recurringType != RecurringType.none ||
        transaction.parentTransactionId != null;

    bool applyToAll = false;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        String title;
        String content;
        String actionText;

        if (transaction.type == TransactionType.income) {
          title = 'Gelir Durumu';
          content = transaction.isPaid
              ? '${transaction.title} geliri alınmadı olarak işaretlemek istiyor musunuz?'
              : '${transaction.title} geliri alındı mı?';
          actionText = transaction.isPaid ? 'Alınmadı' : 'Alındı';
        } else {
          title = 'Ödeme Durumu';
          content = transaction.isPaid
              ? '${transaction.title} ödemesini ödenmedi olarak işaretlemek istiyor musunuz?'
              : '${transaction.title} ödemesi yapıldı mı?';
          actionText = transaction.isPaid ? 'Ödenmedi' : 'Ödendi';
        }

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content),
                if (isRecurring) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: applyToAll,
                        onChanged: (value) {
                          setState(() {
                            applyToAll = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Önceki tekrarlanan işlemlere de uygula',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu seçenek, bu işlem tarihinden önceki tüm tekrarlanan işlemleri aynı şekilde işaretleyecektir.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(actionText),
              ),
            ],
          );
        });
      },
    );

    if (result == true) {
      if (transaction.isPaid) {
        await DatabaseHelper.instance.markPaymentAsUnpaid(transaction.id);
      } else {
        await DatabaseHelper.instance.markPaymentAsPaid(transaction.id);
      }

      // Eğer "tümüne uygula" seçeneği işaretlendiyse tekrarlanan işlemleri güncelle
      if (applyToAll && isRecurring) {
        await DatabaseHelper.instance.updateRecurringTransactionStatus(
            transaction.id, !transaction.isPaid);
      }

      _loadTransactions();
    }
  }
}
