import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';

class AccountDetailPage extends StatefulWidget {
  final Account? account;

  const AccountDetailPage({Key? key, this.account}) : super(key: key);

  @override
  _AccountDetailPageState createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ibanController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = 'wallet';
  int _selectedColor = Colors.blue.value;
  bool _isActive = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.account != null;

    if (_isEditing) {
      // Mevcut hesap bilgilerini form alanlarına doldur
      _nameController.text = widget.account!.name;
      _bankNameController.text = widget.account!.bankName;
      _balanceController.text = widget.account!.balance.toString();
      _accountNumberController.text = widget.account!.accountNumber ?? '';
      _ibanController.text = widget.account!.iban ?? '';
      _descriptionController.text = widget.account!.description ?? '';
      _selectedIcon = widget.account!.iconName ?? 'wallet';
      _selectedColor = widget.account!.colorValue;
      _isActive = widget.account!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _balanceController.dispose();
    _accountNumberController.dispose();
    _ibanController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Hesap Düzenle' : 'Yeni Hesap Ekle'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
              tooltip: 'Hesabı Sil',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconAndColorSelector(),
              const SizedBox(height: 16),

              // Hesap Adı
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hesap Adı *',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen hesap adı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Banka/Kurum Adı
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Banka/Kurum Adı *',
                  prefixIcon: Icon(Icons.account_balance),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen banka adı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bakiye
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Başlangıç Bakiyesi *',
                  prefixIcon: Icon(Icons.money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen bakiye girin';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Geçerli bir miktar girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Hesap Numarası
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Hesap Numarası (İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // IBAN
              TextFormField(
                controller: _ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN (İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.credit_card),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Aktif/Pasif
              SwitchListTile(
                title: const Text('Hesap Aktif'),
                subtitle: const Text(
                    'Pasif hesaplar toplam bakiyeye dahil edilir ancak işlemlerde gösterilmez.'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Kaydet Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveAccount,
                  child: Text(_isEditing ? 'Güncelle' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconAndColorSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesap Görünümü',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // İkon Seçimi
              Column(
                children: [
                  const Text('İkon'),
                  const SizedBox(height: 8),
                  _buildIconSelector(),
                ],
              ),

              // Renk Seçimi
              Column(
                children: [
                  const Text('Renk'),
                  const SizedBox(height: 8),
                  _buildColorSelector(),
                ],
              ),

              // Önizleme
              Column(
                children: [
                  const Text('Önizleme'),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(_selectedColor).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconForName(_selectedIcon),
                      color: Color(_selectedColor),
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconSelector() {
    final icons = {
      'wallet': Icons.account_balance_wallet,
      'bank': Icons.account_balance,
      'card': Icons.credit_card,
      'cash': Icons.money,
      'savings': Icons.savings,
    };

    return DropdownButton<String>(
      value: _selectedIcon,
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedIcon = newValue;
          });
        }
      },
      items: icons.entries.map<DropdownMenuItem<String>>((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Row(
            children: [
              Icon(entry.value),
              const SizedBox(width: 8),
              Text(entry.key.capitalize()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    final colors = [
      Colors.blue.value,
      Colors.red.value,
      Colors.green.value,
      Colors.orange.value,
      Colors.purple.value,
      Colors.teal.value,
      Colors.indigo.value,
      Colors.pink.value,
    ];

    return DropdownButton<int>(
      value: _selectedColor,
      onChanged: (int? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedColor = newValue;
          });
        }
      },
      items: colors.map<DropdownMenuItem<int>>((colorValue) {
        return DropdownMenuItem<int>(
          value: colorValue,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(colorValue),
              shape: BoxShape.circle,
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForName(String iconName) {
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
      default:
        return Icons.account_balance_wallet;
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
            'Bu hesabı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await DatabaseHelper.instance.deleteAccount(widget.account!.id);
      Navigator.of(context).pop(true); // Başarılı silme işlemi dönüşü
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesap başarıyla silindi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silinirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      try {
        final double balance = double.parse(_balanceController.text);

        if (_isEditing) {
          // Mevcut hesabı güncelle
          final updatedAccount = widget.account!.copyWith(
            name: _nameController.text,
            bankName: _bankNameController.text,
            balance: balance,
            accountNumber: _accountNumberController.text.isEmpty
                ? null
                : _accountNumberController.text,
            iban: _ibanController.text.isEmpty ? null : _ibanController.text,
            description: _descriptionController.text.isEmpty
                ? null
                : _descriptionController.text,
            iconName: _selectedIcon,
            colorValue: _selectedColor,
            isActive: _isActive,
            updatedAt: DateTime.now(),
          );

          await DatabaseHelper.instance.updateAccount(updatedAccount);
          Navigator.of(context).pop(true); // Başarılı güncelleme işlemi dönüşü
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesap başarıyla güncellendi')),
          );
        } else {
          // Yeni hesap oluştur
          final newAccount = Account(
            name: _nameController.text,
            bankName: _bankNameController.text,
            balance: balance,
            accountNumber: _accountNumberController.text.isEmpty
                ? null
                : _accountNumberController.text,
            iban: _ibanController.text.isEmpty ? null : _ibanController.text,
            description: _descriptionController.text.isEmpty
                ? null
                : _descriptionController.text,
            iconName: _selectedIcon,
            colorValue: _selectedColor,
            isActive: _isActive,
          );

          await DatabaseHelper.instance.insertAccount(newAccount);
          Navigator.of(context).pop(true); // Başarılı ekleme işlemi dönüşü
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesap başarıyla eklendi')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesap kaydedilirken hata oluştu: $e')),
        );
      }
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
