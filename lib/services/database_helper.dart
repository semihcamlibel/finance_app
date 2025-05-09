import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Yeni sütunları ekle
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN isReceived INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN receivedDate TEXT
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN isPaid INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN paidDate TEXT
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN recurringType INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN recurringCount INTEGER
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN remainingRecurrences INTEGER
      ''');
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN parentTransactionId TEXT
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type INTEGER NOT NULL,
        category INTEGER NOT NULL,
        description TEXT,
        attachmentPath TEXT,
        isReceived INTEGER DEFAULT 0,
        receivedDate TEXT,
        isPaid INTEGER DEFAULT 0,
        paidDate TEXT,
        recurringType INTEGER DEFAULT 0,
        recurringCount INTEGER,
        remainingRecurrences INTEGER,
        parentTransactionId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category INTEGER NOT NULL,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL
      )
    ''');
  }

  // İşlem ekleme
  Future<String> insertTransaction(FinanceTransaction transaction) async {
    final db = await database;
    await db.insert('transactions', transaction.toMap());

    // Eğer yeni bir alacak işlemi ise, otomatik olarak gider olarak da ekle
    if (transaction.type == TransactionType.credit) {
      final expenseTransaction = FinanceTransaction(
        title: 'Verilen: ${transaction.title}',
        amount: transaction.amount,
        date: transaction.date,
        type: TransactionType.expense,
        category: transaction.category,
        description: 'Verilen borç: ${transaction.description ?? ""}',
      );
      await db.insert('transactions', expenseTransaction.toMap());
    }

    return transaction.id;
  }

  // İşlem güncelleme
  Future<int> updateTransaction(FinanceTransaction transaction) async {
    final db = await database;
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // İşlem silme
  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Tüm işlemleri getirme
  Future<List<FinanceTransaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Belirli bir tarihe göre işlemleri getirme
  Future<List<FinanceTransaction>> getTransactionsByDate(DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date LIKE ?',
      whereArgs: ['${date.year}-${date.month.toString().padLeft(2, '0')}%'],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Belirli bir tipe göre işlemleri getirme
  Future<List<FinanceTransaction>> getTransactionsByType(
      TransactionType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type.index],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Toplam gelir hesaplama
  Future<double> getTotalIncome() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = ? AND (
        (isPaid = 1) OR 
        (date <= ? AND recurringType = 0)
      )
    ''', [TransactionType.income.index, now]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Toplam gider hesaplama (ödenmiş ödemeler ve giderler dahil)
  Future<double> getTotalExpense() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE (type = ? AND (isPaid = 1 OR date <= ?)) 
      OR (type = ? AND isPaid = 1)
    ''', [TransactionType.expense.index, now, TransactionType.payment.index]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Toplam borç hesaplama
  Future<double> getTotalDebt() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = ?
    ''', [TransactionType.debt.index]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Toplam alacak hesaplama
  Future<double> getTotalCredit() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = ?
    ''', [TransactionType.credit.index]);
    return result.first['total'] as double? ?? 0.0;
  }

  // Veritabanını kapatma
  Future close() async {
    final db = await database;
    db.close();
  }

  // Alacağı tahsil edildi olarak işaretle
  Future<void> markCreditAsReceived(String id) async {
    final db = await database;

    // Önce mevcut işlemi al
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final transaction = FinanceTransaction.fromMap(maps.first);

      // İşlemi güncelle
      await db.update(
        'transactions',
        {
          'isReceived': 1,
          'receivedDate': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Yeni gelir işlemi oluştur
      final newIncome = FinanceTransaction(
        title: 'Tahsil: ${transaction.title}',
        amount: transaction.amount,
        date: DateTime.now(),
        type: TransactionType.income,
        category: transaction.category,
        description: 'Alacak tahsilatı: ${transaction.description ?? ""}',
      );

      await insertTransaction(newIncome);
    }
  }

  // Alacağı tahsil edilmedi olarak işaretle ve ilgili gelir kaydını sil
  Future<void> markCreditAsNotReceived(String id) async {
    final db = await database;

    // Önce mevcut işlemi al
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final transaction = FinanceTransaction.fromMap(maps.first);

      // İşlemi güncelle
      await db.update(
        'transactions',
        {
          'isReceived': 0,
          'receivedDate': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // İlgili tahsilat gelir kaydını bul ve sil
      final relatedIncomeMaps = await db.query(
        'transactions',
        where: 'title = ? AND type = ?',
        whereArgs: [
          'Tahsil: ${transaction.title}',
          TransactionType.income.index
        ],
      );

      if (relatedIncomeMaps.isNotEmpty) {
        await db.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [relatedIncomeMaps.first['id']],
        );
      }
    }
  }

  // Tahsil edilmemiş alacakları getir
  Future<List<FinanceTransaction>> getUnreceivedCredits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ? AND isReceived = 0',
      whereArgs: [TransactionType.credit.index],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Tahsil edilmiş alacakları getir
  Future<List<FinanceTransaction>> getReceivedCredits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ? AND isReceived = 1',
      whereArgs: [TransactionType.credit.index],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Ödeme işaretleme metodları
  Future<void> markPaymentAsPaid(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'transactions',
      {
        'isPaid': 1,
        'paidDate': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPaymentAsUnpaid(String id) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'isPaid': 0,
        'paidDate': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Ödenmemiş giderleri getir
  Future<List<FinanceTransaction>> getUnpaidExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: '(type = ? OR type = ?) AND isPaid = 0',
      whereArgs: [TransactionType.expense.index, TransactionType.payment.index],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Ödenmiş giderleri getir
  Future<List<FinanceTransaction>> getPaidExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: '(type = ? OR type = ?) AND isPaid = 1',
      whereArgs: [TransactionType.expense.index, TransactionType.payment.index],
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Örnek verileri ekleme
  Future<void> insertSampleData() async {
    final List<FinanceTransaction> sampleTransactions = [
      // Gelirler
      FinanceTransaction(
        title: 'Ocak Maaşı',
        amount: 12500.0,
        date: DateTime(2024, 1, 5),
        type: TransactionType.income,
        category: TransactionCategory.salary,
        description: '2024 Ocak ayı maaş ödemesi',
      ),
      FinanceTransaction(
        title: 'Freelance Proje',
        amount: 5000.0,
        date: DateTime(2024, 1, 15),
        type: TransactionType.income,
        category: TransactionCategory.investment,
        description: 'Web sitesi geliştirme projesi',
      ),

      // Giderler
      FinanceTransaction(
        title: 'Market Alışverişi',
        amount: 850.0,
        date: DateTime(2024, 1, 6),
        type: TransactionType.expense,
        category: TransactionCategory.food,
        description: 'Aylık market alışverişi',
      ),
      FinanceTransaction(
        title: 'Elektrik Faturası',
        amount: 450.0,
        date: DateTime(2024, 1, 12),
        type: TransactionType.expense,
        category: TransactionCategory.bills,
      ),
      FinanceTransaction(
        title: 'Akaryakıt',
        amount: 1200.0,
        date: DateTime(2024, 1, 8),
        type: TransactionType.expense,
        category: TransactionCategory.transport,
      ),

      // Borçlar
      FinanceTransaction(
        title: 'Kredi Kartı Borcu',
        amount: 3500.0,
        date: DateTime(2024, 1, 10),
        type: TransactionType.debt,
        category: TransactionCategory.bills,
        description: 'Ocak ayı kredi kartı borcu',
      ),
      FinanceTransaction(
        title: 'İhtiyaç Kredisi',
        amount: 15000.0,
        date: DateTime(2024, 1, 1),
        type: TransactionType.debt,
        category: TransactionCategory.other,
        description: '36 ay vadeli ihtiyaç kredisi',
      ),

      // Alacaklar (bazıları tahsil edilmiş)
      FinanceTransaction(
        title: 'Arkadaşa Verilen Borç',
        amount: 2000.0,
        date: DateTime(2024, 1, 20),
        type: TransactionType.credit,
        category: TransactionCategory.other,
        description: 'Ahmet\'e verilen borç',
        isReceived: false,
      ),
      FinanceTransaction(
        title: 'İş için Verilen Avans',
        amount: 5000.0,
        date: DateTime(2024, 1, 10),
        type: TransactionType.credit,
        category: TransactionCategory.other,
        description: 'Proje için verilen avans',
        isReceived: true,
        receivedDate: DateTime(2024, 1, 25),
      ),

      // Ödemeler
      FinanceTransaction(
        title: 'Kredi Taksiti',
        amount: 1250.0,
        date: DateTime(2024, 1, 15),
        type: TransactionType.payment,
        category: TransactionCategory.bills,
        description: 'Ocak ayı kredi taksiti ödemesi',
      ),
    ];

    final db = await database;
    await db.transaction((txn) async {
      for (var transaction in sampleTransactions) {
        await txn.insert('transactions', transaction.toMap());
      }
    });
  }

  // Tüm verileri silme
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
  }

  // Tekrarlayan işlem oluşturma
  Future<void> createRecurringTransaction(
      FinanceTransaction transaction) async {
    final db = await database;

    // Ana işlemi ekle
    final mainTransaction = transaction.copyWith(
      parentTransactionId: null,
      remainingRecurrences: transaction.recurringCount,
    );
    final mainId = await insertTransaction(mainTransaction);

    if (transaction.recurringCount != null) {
      // Belirli sayıda tekrar
      for (int i = 1; i < transaction.recurringCount!; i++) {
        final nextDate = transaction.recurringType == RecurringType.monthly
            ? DateTime(transaction.date.year, transaction.date.month + i,
                transaction.date.day)
            : DateTime(transaction.date.year + i, transaction.date.month,
                transaction.date.day);

        final recurringTransaction = FinanceTransaction(
          title: transaction.title,
          amount: transaction.amount,
          date: nextDate,
          type: transaction.type,
          category: transaction.category,
          description: transaction.description,
          parentTransactionId: mainId,
          remainingRecurrences: transaction.recurringCount! - i,
          recurringType: transaction.recurringType,
          recurringCount: transaction.recurringCount,
          isPaid: false,
          paidDate: null,
          isReceived: false,
          receivedDate: null,
        );

        await insertTransaction(recurringTransaction);
      }
    }
  }

  // Tekrarlayan işlemleri güncelleme
  Future<void> updateRecurringTransactions(
      String parentId, FinanceTransaction updatedTransaction) async {
    final db = await database;

    // Gelecek tarihli tekrarlayan işlemleri güncelle
    final now = DateTime.now();
    final List<Map<String, dynamic>> futureTransactions = await db.query(
      'transactions',
      where: 'parentTransactionId = ? AND date > ?',
      whereArgs: [parentId, now.toIso8601String()],
    );

    for (var transaction in futureTransactions) {
      final existingDate = DateTime.parse(transaction['date']);
      final daysDiff =
          existingDate.difference(DateTime.parse(transaction['date'])).inDays;

      final updatedDate =
          updatedTransaction.recurringType == RecurringType.monthly
              ? DateTime(
                  updatedTransaction.date.year,
                  updatedTransaction.date.month + (daysDiff ~/ 30),
                  updatedTransaction.date.day)
              : DateTime(updatedTransaction.date.year + (daysDiff ~/ 365),
                  updatedTransaction.date.month, updatedTransaction.date.day);

      await db.update(
        'transactions',
        {
          'title': updatedTransaction.title,
          'amount': updatedTransaction.amount,
          'date': updatedDate.toIso8601String(),
          'type': updatedTransaction.type.index,
          'category': updatedTransaction.category.index,
          'description': updatedTransaction.description,
        },
        where: 'id = ?',
        whereArgs: [transaction['id']],
      );
    }
  }

  // Tekrarlayan işlemleri silme
  Future<void> deleteRecurringTransactions(String parentId) async {
    final db = await database;

    // Gelecek tarihli tekrarlayan işlemleri sil
    final now = DateTime.now();
    await db.delete(
      'transactions',
      where: 'parentTransactionId = ? AND date > ?',
      whereArgs: [parentId, now.toIso8601String()],
    );
  }

  // Ana işleme bağlı tüm tekrarlayan işlemleri getir
  Future<List<FinanceTransaction>> getRecurringTransactions(
      String parentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'parentTransactionId = ? OR id = ?',
      whereArgs: [parentId, parentId],
      orderBy: 'date ASC',
    );
    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Bütçe işlemleri
  Future<void> setBudget(
      TransactionCategory category, double amount, int month, int year) async {
    final db = await database;
    await db.insert(
      'budgets',
      {
        'id': const Uuid().v4(),
        'category': category.index,
        'amount': amount,
        'month': month,
        'year': year,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<TransactionCategory, double>> getBudgets(
      int month, int year) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );

    final Map<TransactionCategory, double> budgets = {};
    for (var map in maps) {
      budgets[TransactionCategory.values[map['category']]] = map['amount'];
    }
    return budgets;
  }

  Future<void> deleteBudget(
      TransactionCategory category, int month, int year) async {
    final db = await database;
    await db.delete(
      'budgets',
      where: 'category = ? AND month = ? AND year = ?',
      whereArgs: [category.index, month, year],
    );
  }

  // Bütçe aşım bildirimleri için yardımcı metod
  Future<List<Map<String, dynamic>>> getOverBudgetCategories(
      int month, int year) async {
    final db = await database;
    final budgets = await getBudgets(month, year);
    final transactions = await getTransactionsByDate(DateTime(year, month));

    final List<Map<String, dynamic>> overBudgetCategories = [];

    // Her kategori için harcamaları hesapla
    for (var category in budgets.keys) {
      final budget = budgets[category] ?? 0;
      final expense = transactions
          .where((t) =>
              t.type == TransactionType.expense && t.category == category)
          .fold(0.0, (sum, t) => sum + t.amount);

      if (expense > budget) {
        overBudgetCategories.add({
          'category': category,
          'budget': budget,
          'expense': expense,
          'overspend': expense - budget,
        });
      }
    }

    return overBudgetCategories;
  }

  static NumberFormat getCurrencyFormat(String currencySymbol) {
    switch (currencySymbol) {
      case '\$':
        return NumberFormat.currency(
            locale: 'en_US', symbol: '\$', decimalDigits: 2);
      case '€':
        return NumberFormat.currency(
            locale: 'de_DE', symbol: '€', decimalDigits: 2);
      case '£':
        return NumberFormat.currency(
            locale: 'en_GB', symbol: '£', decimalDigits: 2);
      case '₺':
      default:
        return NumberFormat.currency(
            locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    }
  }

  // Son X gün içindeki işlemleri getiren fonksiyon
  Future<List<FinanceTransaction>> getTransactionsForLastDays(int days) async {
    final db = await database;
    final date = DateTime.now().subtract(Duration(days: days));
    final dateStr = date.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ?',
      whereArgs: [dateStr],
      orderBy: 'date DESC',
    );

    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }

  // Son X adet işlemi getiren fonksiyon
  Future<List<FinanceTransaction>> getRecentTransactions(int limit) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
    );

    return List.generate(
        maps.length, (i) => FinanceTransaction.fromMap(maps[i]));
  }
}
