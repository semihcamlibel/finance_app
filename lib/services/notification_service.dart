import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Bildirime tıklandığında yapılacak işlemler
      },
    );

    // Android için bildirim izni kontrolü
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      // Eski sürümlerde requestNotificationsPermission() metodu yok,
      // bu özelliğin yerine AndroidManifest.xml'de izinlerin tanımlanması gerekiyor
      debugPrint(
          'Android bildirim izinleri AndroidManifest.xml üzerinden kontrol edilmeli');
    }
  }

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'finance_app_channel',
        'Finans Bildirimleri',
        channelDescription: 'Finans uygulaması bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
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

      final zonedTime = tz.TZDateTime.from(targetDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        zonedTime,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Bildirim başarıyla planlandı: $zonedTime');
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

      await _notifications.show(
        id,
        title,
        body,
        _notificationDetails,
      );
      debugPrint('Anlık bildirim başarıyla gönderildi');
    } catch (e) {
      debugPrint('Anlık bildirim gönderilirken hata oluştu: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
