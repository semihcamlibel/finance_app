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
      // 18.0.1 sürümünde direkt olarak bildirim izinleri AndroidManifest.xml
      // üzerinden kontrol ediliyor olabilir, bu nedenle manuel istek kısmını devre dışı bırakıyoruz
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

        // Bugünün tarihini alıp, bildirim zamanını ayarlayalım
        final today = DateTime.now();
        // Hedef tarihe kaç gün kaldığını hesaplayalım
        final difference = scheduledDate.difference(today).inDays;

        // Eğer bildirim hedef tarihten X gün önce gösterilecekse ve
        // bugün + daysBefore günü hedef tarihe eşit veya daha küçükse bildirim gösterilmeli
        if (difference <= daysBefore) {
          // Bugün bildirim gösterilmeli, zamanı ayarlayalım
          targetDate = DateTime(
            today.year,
            today.month,
            today.day,
            notificationTime.hour,
            notificationTime.minute,
          );

          // Eğer belirlenen saat geçtiyse, bildirim hemen gösterilsin
          if (targetDate.isBefore(today)) {
            targetDate = today.add(const Duration(minutes: 1));
          }
        } else {
          // Gelecekteki bir tarih için bildirim planla
          targetDate = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day - daysBefore, // X gün önce
            notificationTime.hour,
            notificationTime.minute,
          );
        }
      }

      final zonedTime = tz.TZDateTime.from(targetDate, tz.local);

      debugPrint(
          'Bildirim planlanıyor - Hedef Tarih: $scheduledDate, Bildirim Tarihi: $targetDate');

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

  // Zamanlanmış bildirim testi için
  Future<void> testScheduledNotification() async {
    // 1. Hemen gösterilecek bir bildirim
    await showInstantNotification(
      id: 9999,
      title: "Anlık Bildirim Testi",
      body: "Bu bir anlık bildirim testidir. Şimdi gösterilmelidir.",
    );

    // 2. 1 dakika sonra gösterilecek bir bildirim
    final oneMinuteLater = DateTime.now().add(const Duration(minutes: 1));
    await showNotification(
      id: 9998,
      title: "1 Dakika Sonra Bildirim",
      body:
          "Bu bildirim 1 dakika sonra gösterilmelidir. Saat: ${oneMinuteLater.hour}:${oneMinuteLater.minute}",
      scheduledDate: oneMinuteLater,
      useCustomTime: true,
    );

    // 3. Bugünün belirli bir saatinde gösterilecek bildirim
    final todayAt = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      DateTime.now().hour,
      DateTime.now().minute + 2, // Şimdiden 2 dakika sonra
    );

    await showNotification(
      id: 9997,
      title: "Bugün için Planlı Bildirim",
      body:
          "Bu bildirim belirlenen saatte gösterilmelidir: ${todayAt.hour}:${todayAt.minute}",
      scheduledDate: todayAt,
      useCustomTime: true,
    );

    debugPrint(
        "Test bildirimleri oluşturuldu: Anlık, 1 dakika sonra ve Bugün ${todayAt.hour}:${todayAt.minute}");
  }
}
