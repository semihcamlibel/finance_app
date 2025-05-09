import 'package:uuid/uuid.dart';

enum TransactionType {
  income, // Gelir
  expense, // Gider
  debt, // Borç
  credit, // Alacak
  payment // Ödeme
}

enum TransactionCategory {
  salary, // Maaş
  investment, // Yatırım
  shopping, // Alışveriş
  bills, // Faturalar
  food, // Yemek
  transport, // Ulaşım
  health, // Sağlık
  education, // Eğitim
  entertainment, // Eğlence
  other // Diğer
}

enum RecurringType {
  none, // Tekrar etmeyen
  monthly, // Aylık
  yearly // Yıllık
}

class FinanceTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final String? attachmentPath;
  final bool isReceived; // Alacağın alınıp alınmadığını kontrol eden alan
  final DateTime? receivedDate; // Alacağın alındığı tarih
  final bool isPaid; // Ödemenin yapılıp yapılmadığını kontrol eden alan
  final DateTime? paidDate; // Ödemenin yapıldığı tarih
  final RecurringType recurringType; // Tekrar tipi
  final int? recurringCount; // Tekrar sayısı (null ise süresiz)
  final int? remainingRecurrences; // Kalan tekrar sayısı
  final String? parentTransactionId; // Tekrarlayan işlemin ana işlem ID'si

  FinanceTransaction({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.description,
    this.attachmentPath,
    this.isReceived = false,
    this.receivedDate,
    this.isPaid = false,
    this.paidDate,
    this.recurringType = RecurringType.none,
    this.recurringCount,
    this.remainingRecurrences,
    this.parentTransactionId,
  }) : id = id ?? const Uuid().v4();

  // isCredit getter'ı
  bool get isCredit => type == TransactionType.credit;

  // isDebt getter'ı
  bool get isDebt => type == TransactionType.debt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.index,
      'category': category.index,
      'description': description,
      'attachmentPath': attachmentPath,
      'isReceived': isReceived ? 1 : 0,
      'receivedDate': receivedDate?.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
      'paidDate': paidDate?.toIso8601String(),
      'recurringType': recurringType.index,
      'recurringCount': recurringCount,
      'remainingRecurrences': remainingRecurrences,
      'parentTransactionId': parentTransactionId,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values[map['type']],
      category: TransactionCategory.values[map['category']],
      description: map['description'],
      attachmentPath: map['attachmentPath'],
      isReceived: map['isReceived'] == 1,
      receivedDate: map['receivedDate'] != null
          ? DateTime.parse(map['receivedDate'])
          : null,
      isPaid: map['isPaid'] == 1,
      paidDate:
          map['paidDate'] != null ? DateTime.parse(map['paidDate']) : null,
      recurringType: RecurringType.values[map['recurringType'] ?? 0],
      recurringCount: map['recurringCount'],
      remainingRecurrences: map['remainingRecurrences'],
      parentTransactionId: map['parentTransactionId'],
    );
  }

  FinanceTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    TransactionCategory? category,
    String? description,
    String? attachmentPath,
    bool? isReceived,
    DateTime? receivedDate,
    bool? isPaid,
    DateTime? paidDate,
    RecurringType? recurringType,
    int? recurringCount,
    int? remainingRecurrences,
    String? parentTransactionId,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      isReceived: isReceived ?? this.isReceived,
      receivedDate: receivedDate ?? this.receivedDate,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      recurringType: recurringType ?? this.recurringType,
      recurringCount: recurringCount ?? this.recurringCount,
      remainingRecurrences: remainingRecurrences ?? this.remainingRecurrences,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
    );
  }
}
