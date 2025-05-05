import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddTransactionPage extends StatefulWidget {
  final FinanceTransaction? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TextEditingController _recurringCountController =
      TextEditingController();

  late DateTime _selectedDate;
  late TransactionType _selectedType;
  late TransactionCategory _selectedCategory;
  late RecurringType _selectedRecurringType;
  bool _showRecurringOptions = false;
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (widget.transaction != null) {
      // Düzenleme modu
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _descriptionController.text = widget.transaction!.description ?? '';
      _selectedDate = widget.transaction!.date;
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedRecurringType = widget.transaction!.recurringType;
      if (widget.transaction!.recurringCount != null) {
        _recurringCountController.text =
            widget.transaction!.recurringCount.toString();
      }
      _showRecurringOptions =
          widget.transaction!.recurringType != RecurringType.none;
    } else {
      // Yeni işlem modu
      _selectedDate = DateTime.now();
      _selectedType = TransactionType.expense;
      _selectedCategory = TransactionCategory.other;
      _selectedRecurringType = RecurringType.none;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _recurringCountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      try {
        final transaction = FinanceTransaction(
          id: widget.transaction?.id,
          title: _titleController.text,
          amount: double.parse(_amountController.text.replaceAll(',', '.')),
          date: _selectedDate,
          type: _selectedType,
          category: _selectedCategory,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          isReceived: widget.transaction?.isReceived ?? false,
          receivedDate: widget.transaction?.receivedDate,
          isPaid: widget.transaction?.isPaid ??
              (_selectedType != TransactionType.income &&
                  _selectedType != TransactionType.payment &&
                  _selectedType != TransactionType.expense),
          paidDate: widget.transaction?.paidDate,
          recurringType: _showRecurringOptions
              ? _selectedRecurringType
              : RecurringType.none,
          recurringCount:
              _showRecurringOptions && _recurringCountController.text.isNotEmpty
                  ? int.parse(_recurringCountController.text)
                  : null,
        );

        if (widget.transaction != null) {
          // Düzenleme modu
          if (transaction.recurringType != RecurringType.none &&
              widget.transaction!.parentTransactionId == null) {
            // Ana tekrarlayan işlem güncelleniyor
            await DatabaseHelper.instance.updateRecurringTransactions(
                widget.transaction!.id, transaction);
          }
          await DatabaseHelper.instance.updateTransaction(transaction);
        } else {
          // Yeni işlem modu
          if (transaction.recurringType != RecurringType.none) {
            await DatabaseHelper.instance
                .createRecurringTransaction(transaction);
          } else {
            await DatabaseHelper.instance.insertTransaction(transaction);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İşlem başarıyla kaydedildi'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata oluştu: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.transaction == null ? 'Yeni İşlem' : 'İşlemi Düzenle'),
      ),
      body: Hero(
        tag: widget.transaction != null
            ? 'transaction_${widget.transaction!.id}'
            : 'new_transaction',
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bir başlık girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Tutar',
                      border: const OutlineInputBorder(),
                      prefixText: '$_selectedCurrency ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[,.]?\d*')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen bir tutar girin';
                      }
                      if (double.tryParse(value.replaceAll(',', '.')) == null) {
                        return 'Geçerli bir tutar girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Tarih',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'İşlem Tipi',
                      border: OutlineInputBorder(),
                    ),
                    items: TransactionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTransactionTypeText(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                        // Sadece gelir, gider ve ödeme tipleri için tekrarlama seçeneği göster
                        _showRecurringOptions =
                            value == TransactionType.income ||
                                value == TransactionType.expense ||
                                value == TransactionType.payment;
                        if (!_showRecurringOptions) {
                          _selectedRecurringType = RecurringType.none;
                          _recurringCountController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TransactionCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: TransactionCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(_getTransactionCategoryText(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  if (_showRecurringOptions) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Tekrarlama Seçenekleri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RecurringType>(
                      value: _selectedRecurringType,
                      decoration: const InputDecoration(
                        labelText: 'Tekrarlama Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: RecurringType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_getRecurringTypeText(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRecurringType = value!;
                        });
                      },
                    ),
                    if (_selectedRecurringType != RecurringType.none) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _recurringCountController,
                        decoration: const InputDecoration(
                          labelText: 'Tekrar Sayısı (Boş bırakılırsa süresiz)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final count = int.tryParse(value);
                            if (count == null || count < 2) {
                              return 'Tekrar sayısı en az 2 olmalıdır';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      child: Text(
                          widget.transaction != null ? 'Güncelle' : 'Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  String _getTransactionCategoryText(TransactionCategory category) {
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
}
