import 'package:uuid/uuid.dart';

class Account {
  final String id;
  final String name;
  final String bankName;
  final double balance;
  final String? accountNumber;
  final String? iban;
  final String? description;
  final String? iconName;
  final int colorValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Account({
    String? id,
    required this.name,
    required this.bankName,
    required this.balance,
    this.accountNumber,
    this.iban,
    this.description,
    this.iconName,
    required this.colorValue,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'balance': balance,
      'accountNumber': accountNumber,
      'iban': iban,
      'description': description,
      'iconName': iconName,
      'colorValue': colorValue,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      bankName: map['bankName'],
      balance: map['balance'],
      accountNumber: map['accountNumber'],
      iban: map['iban'],
      description: map['description'],
      iconName: map['iconName'],
      colorValue: map['colorValue'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? bankName,
    double? balance,
    String? accountNumber,
    String? iban,
    String? description,
    String? iconName,
    int? colorValue,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      balance: balance ?? this.balance,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
