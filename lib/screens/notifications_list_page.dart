import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsListPage extends StatefulWidget {
  const NotificationsListPage({Key? key}) : super(key: key);

  @override
  State<NotificationsListPage> createState() => _NotificationsListPageState();
}

class _NotificationsListPageState extends State<NotificationsListPage> {
  late NumberFormat currencyFormat;
  String _selectedCurrency = '₺';
  bool _hideAmounts = false;
  bool _isLoading = true;

  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNotifications();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCurrency = prefs.getString('currency') ?? '₺';
      currencyFormat = DatabaseHelper.getCurrencyFormat(_selectedCurrency);
      _hideAmounts = prefs.getBool('hideAmounts') ?? false;
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    // Bekleyen ödemeleri al
    final upcomingPayments = await _getUpcomingPayments();

    // Gecikmiş ödemeleri al
    final overduePayments = await _getOverduePayments();

    // Bütçe aşımı bildirimlerini al
    final budgetAlerts = await _getBudgetAlerts();

    // Tüm bildirimleri birleştir ve tarihe göre sırala
    setState(() {
      _notifications = [
        ...upcomingPayments,
        ...overduePayments,
        ...budgetAlerts
      ];
      _notifications.sort((a, b) => b.date.compareTo(a.date)); // Yeniden eskiye
      _isLoading = false;
    });
  }

  Future<List<NotificationItem>> _getUpcomingPayments() async {
    final unpaidExpenses = await DatabaseHelper.instance.getUnpaidExpenses();
    final now = DateTime.now();

    return unpaidExpenses
        .where((transaction) =>
            transaction.date.isAfter(now) &&
            transaction.date.difference(now).inDays <= 7)
        .map((transaction) {
      final daysRemaining = transaction.date.difference(now).inDays;
      String message;

      if (daysRemaining == 0) {
        message = "Bugün ödenecek";
      } else if (daysRemaining == 1) {
        message = "Yarın ödenecek";
      } else {
        message = "$daysRemaining gün içinde ödenecek";
      }

      return NotificationItem(
        id: transaction.id,
        title: transaction.title,
        message: message,
        amount: transaction.amount,
        date: transaction.date,
        type: NotificationType.payment,
        isRead: false,
      );
    }).toList();
  }

  Future<List<NotificationItem>> _getOverduePayments() async {
    final unpaidExpenses = await DatabaseHelper.instance.getUnpaidExpenses();
    final now = DateTime.now();

    return unpaidExpenses
        .where((transaction) => transaction.date.isBefore(now))
        .map((transaction) {
      final daysOverdue = now.difference(transaction.date).inDays;
      String message;

      if (daysOverdue == 0) {
        message = "Bugün ödenmesi gerekiyordu";
      } else if (daysOverdue == 1) {
        message = "Dün ödenmesi gerekiyordu";
      } else {
        message = "$daysOverdue gün gecikmiş ödeme";
      }

      return NotificationItem(
        id: "overdue_${transaction.id}",
        title: transaction.title,
        message: message,
        amount: transaction.amount,
        date: transaction.date,
        type: NotificationType.overdue,
        isRead: false,
      );
    }).toList();
  }

  Future<List<NotificationItem>> _getBudgetAlerts() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final overBudgetCategories = await DatabaseHelper.instance
        .getOverBudgetCategories(currentMonth, currentYear);

    return overBudgetCategories.map((category) {
      final categoryName =
          _getCategoryName(category['category'] as TransactionCategory);
      final overspend = category['overspend'] as double;

      return NotificationItem(
        id: "${categoryName}_${currentMonth}_${currentYear}",
        title: "Bütçe Aşımı: $categoryName",
        message: "Bu ay için $categoryName bütçenizi aştınız",
        amount: overspend,
        date: now,
        type: NotificationType.budget,
        isRead: false,
      );
    }).toList();
  }

  String _getCategoryName(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salary:
        return "Maaş";
      case TransactionCategory.investment:
        return "Yatırım";
      case TransactionCategory.shopping:
        return "Alışveriş";
      case TransactionCategory.bills:
        return "Faturalar";
      case TransactionCategory.food:
        return "Yemek";
      case TransactionCategory.transport:
        return "Ulaşım";
      case TransactionCategory.health:
        return "Sağlık";
      case TransactionCategory.education:
        return "Eğitim";
      case TransactionCategory.entertainment:
        return "Eğlence";
      case TransactionCategory.other:
      default:
        return "Diğer";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications),
            const SizedBox(width: 8),
            const Text('Bildirimler'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Tüm bildirimleri temizle
              setState(() {
                _notifications.clear();
              });
            },
            tooltip: 'Tümünü Temizle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Bildirim Bulunmuyor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bildirimler geldiğinde burada görünecek',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _notifications.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    Color cardColor;
    IconData iconData;

    switch (notification.type) {
      case NotificationType.payment:
        cardColor = AppTheme.warningColor;
        iconData = Icons.payment;
        break;
      case NotificationType.budget:
        cardColor = AppTheme.errorColor;
        iconData = Icons.account_balance_wallet;
        break;
      case NotificationType.income:
        cardColor = AppTheme.incomeColor;
        iconData = Icons.arrow_upward;
        break;
      case NotificationType.overdue:
        cardColor = AppTheme.errorColor;
        iconData = Icons.access_time;
        break;
      default:
        cardColor = AppTheme.greyColor;
        iconData = Icons.notifications;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead
              ? Colors.transparent
              : cardColor.withOpacity(0.3),
          width: notification.isRead ? 0 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Bildirime tıklandığında okundu olarak işaretle
          setState(() {
            final index = _notifications.indexOf(notification);
            if (index != -1) {
              _notifications[index] = notification.copyWith(isRead: true);
            }
          });

          // Burada bildirime göre detay sayfasına yönlendirme yapılabilir
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  iconData,
                  color: cardColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: AppTheme.greyColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM, HH:mm', 'tr_TR')
                              .format(notification.date),
                          style: TextStyle(
                            color: AppTheme.greyColor,
                            fontSize: 12,
                          ),
                        ),
                        if (notification.amount != 0)
                          Text(
                            _hideAmounts
                                ? '****'
                                : currencyFormat
                                    .format(notification.amount.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cardColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum NotificationType { payment, budget, income, overdue, other }

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final double amount;
  final DateTime date;
  final NotificationType type;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.amount,
    required this.date,
    required this.type,
    this.isRead = false,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    double? amount,
    DateTime? date,
    NotificationType? type,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }
}
