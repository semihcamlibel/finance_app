import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'finance_app_channel',
          channelName: 'Finans Bildirimleri',
          channelDescription: 'Finans uygulaması bildirimleri',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          enableVibration: true,
          playSound: true,
        ),
      ],
    );

    // Android için bildirim izni kontrolü
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      debugPrint('Bildirim izni alınacak');
      // Burada izin isteme işlemini yapabilirsiniz
      // await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<bool> _shouldShowNotification(String type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case 'payment':
        return prefs.getBool('showPaymentNotifications') ?? true;
      case 'income':
        return prefs.getBool('showIncomeNotifications') ?? true;
      case 'budget':
        return prefs.getBool('showBudgetNotifications') ?? true;
      default:
        return true;
    }
  }

  Future<TimeOfDay> _getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notificationTimeHour') ?? 9;
    final minute = prefs.getInt('notificationTimeMinute') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<int> _getNotificationDaysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notificationDaysBefore') ?? 3;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String type = 'general',
    bool useCustomTime = false,
  }) async {
    try {
      final shouldShow = await _shouldShowNotification(type);
      if (!shouldShow) {
        debugPrint(
            '$type bildirimleri kapalı olduğu için bildirim gösterilmedi');
        return;
      }

      DateTime targetDate;
      if (useCustomTime) {
        // Test bildirimleri için özel zaman kullan
        targetDate = scheduledDate;
      } else {
        // Normal bildirimler için ayarlanan zamanı kullan
        final notificationTime = await _getNotificationTime();
        final daysBefore = await _getNotificationDaysBefore();

        targetDate = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day - daysBefore,
          notificationTime.hour,
          notificationTime.minute,
        );

        // Eğer hedef zaman geçmişse, bir sonraki güne ayarla
        if (targetDate.isBefore(DateTime.now())) {
          targetDate = targetDate.add(const Duration(days: 1));
        }
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'finance_app_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(date: targetDate),
      );

      debugPrint('Bildirim başarıyla planlandı: $targetDate');
    } catch (e) {
      debugPrint('Bildirim planlanırken hata oluştu: $e');
    }
  }

  // Test bildirimleri için özel metod
  Future<void> showTestNotification({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String type = 'general',
  }) async {
    final now = DateTime.now();
    await showNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: now.add(delay),
      type: type,
      useCustomTime: true,
    );
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      final shouldShow = await _shouldShowNotification(type);
      if (!shouldShow) {
        debugPrint(
            '$type bildirimleri kapalı olduğu için bildirim gösterilmedi');
        return;
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'finance_app_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
        ),
      );

      debugPrint('Anlık bildirim başarıyla gönderildi');
    } catch (e) {
      debugPrint('Anlık bildirim gönderilirken hata oluştu: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}
