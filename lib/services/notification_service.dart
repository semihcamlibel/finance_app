import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService._();

  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('Bildirim servisi başlatılıyor...');
    tz.initializeTimeZones();

    // Yerel zaman dilimini ayarla
    final String currentTimeZone = DateTime.now().timeZoneName;
    debugPrint('Yerel zaman dilimi: $currentTimeZone');

    // Varsayılan saat ve gün önce değerlerini kontrol et ve yoksa kaydet
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('notificationTimeHour')) {
      await prefs.setInt('notificationTimeHour', 9); // Varsayılan saat 9:00
    }
    if (!prefs.containsKey('notificationTimeMinute')) {
      await prefs.setInt('notificationTimeMinute', 0);
    }
    if (!prefs.containsKey('notificationDaysBefore')) {
      await prefs.setInt('notificationDaysBefore', 3); // Varsayılan 3 gün önce
    }

    // Varsayılan bildirim türü ayarlarını kontrol et
    if (!prefs.containsKey('showPaymentNotifications')) {
      await prefs.setBool('showPaymentNotifications', true);
    }
    if (!prefs.containsKey('showIncomeNotifications')) {
      await prefs.setBool('showIncomeNotifications', true);
    }
    if (!prefs.containsKey('showBudgetNotifications')) {
      await prefs.setBool('showBudgetNotifications', true);
    }

    debugPrint(
        'Bildirim ayarları: Saat ${await _getNotificationTime().then((t) => '${t.hour}:${t.minute}')}, '
        '${await _getNotificationDaysBefore()} gün önce');

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
        debugPrint('Bildirime tıklandı: ${details.payload}');
      },
    );

    // Android için bildirim izni kontrolü
    if (Platform.isAndroid) {
      final platform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (platform != null) {
        try {
          // Mevcut izinleri kontrol et
          final bool? areNotificationsEnabled =
              await platform.areNotificationsEnabled();
          debugPrint('Bildirim izinleri durumu: $areNotificationsEnabled');

          // Eğer bildirimler açık değilse, izin iste
          if (areNotificationsEnabled == false) {
            try {
              // Bazı sürümlerde requestPermission yerine başka bir isim kullanılabilir
              // Bu yüzden burayı atlıyoruz, AndroidManifest.xml'deki izinler yeterli olmalı
              debugPrint(
                  'Bildirim izni gerekiyor, ancak otomatik istek yapılamıyor');
            } catch (e) {
              debugPrint('Bildirim izni istenirken hata: $e');
            }
          }

          // Tam zamanlı alarm izinlerini kontrol etmeye çalış
          try {
            final bool? hasExactAlarmPermission =
                await platform.canScheduleExactNotifications();
            debugPrint('Tam zamanlı bildirim izni: $hasExactAlarmPermission');
          } catch (e) {
            debugPrint('Tam zamanlı bildirim izni kontrolünde hata: $e');
          }
        } catch (e) {
          debugPrint('Bildirim izinleri kontrolünde hata: $e');
        }
      }
    }

    // Uygulama başladığında, daha önce kaydedilmiş bildirimleri yeniden planla
    await rescheduleAllNotifications();

    _initialized = true;
    debugPrint('Bildirim servisi başarıyla başlatıldı');
  }

  NotificationDetails get _notificationDetails {
    return NotificationDetails(
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
        // Bildirim ayarlarını güçlendirme
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        ongoing: false,
        visibility: NotificationVisibility.public,
        actions: [
          AndroidNotificationAction(
            'view_action',
            'Görüntüle',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
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
      if (!_initialized) {
        await initialize();
      }

      final shouldShow = await _shouldShowNotification(type);
      if (!shouldShow) {
        debugPrint(
            '$type bildirimleri kapalı olduğu için bildirim gösterilmedi');
        return;
      }

      final now = DateTime.now();
      final daysBefore = await _getNotificationDaysBefore();
      final notificationTime = await _getNotificationTime();

      // Hedef tarihe kaç gün kaldığını hesaplayalım
      final today = DateTime(now.year, now.month, now.day);
      final scheduleDay =
          DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final difference = scheduleDay.difference(today).inDays;

      debugPrint(
          'Hedef tarih: $scheduleDay, Bugün: $today, Fark: $difference gün, Bildirim: $daysBefore gün önce');

      // Özel zamanlı bildirim mi, yoksa ayarlarda belirlenen zamana göre mi?
      if (useCustomTime) {
        // Test bildirimleri için özel zaman kullan
        // TZDateTime kullanarak yerel saat dilimine göre hesaplayalım
        final zonedTime = tz.TZDateTime.from(scheduledDate, tz.local);

        // Geçmiş bir zamana bildirim planlanıyorsa
        if (zonedTime.isBefore(tz.TZDateTime.now(tz.local))) {
          debugPrint(
              'Geçmiş zaman tespit edildi, bildirim 5 saniye sonra gösterilecek');
          final newTime =
              tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
          _scheduleExactNotification(id, title, body, newTime, type);
        } else {
          _scheduleExactNotification(id, title, body, zonedTime, type);
        }
      } else {
        // Kullanıcının ayarladığı bildirim günleri için işlem yapalım

        // Eğer bugün (difference günü) bildirim günleri içindeyse
        if (0 <= difference && difference <= daysBefore) {
          // Bugün bir bildirim gösterilmeli
          _scheduleNotificationForToday(
              id, title, body, notificationTime, type);
          debugPrint(
              'Bugün bildirim planlandı (kalan gün: $difference, bildirilecek gün: $daysBefore içinde)');
        }

        // Birden fazla gün bildirim göstermek için, her gün için farklı ID'lerle bildirim planla
        // daysBefore günden başlayarak geriye doğru say ve her gün için ayrı bildirim oluştur
        for (int i = daysBefore; i > 0; i--) {
          // Eğer bugünkü bildirim zaten yukarıda planlandıysa atlayalım
          if (difference == i) continue;

          // Hedef tarihten i gün öncesi için bir bildirim planla
          final notificationDay = scheduleDay.subtract(Duration(days: i));

          // Eğer bildirim günü bugünden önceyse, bu günü atlayalım
          if (notificationDay.isBefore(today)) continue;

          // Her gün için benzersiz ID oluştur (temel ID + gün offseti)
          final uniqueId = id + (i * 1000);

          // O gün için bildirimi planla
          final notificationDateTime = DateTime(
            notificationDay.year,
            notificationDay.month,
            notificationDay.day,
            notificationTime.hour,
            notificationTime.minute,
          );

          final zonedTime = tz.TZDateTime.from(notificationDateTime, tz.local);

          // Eğer bu zaman geçmişte kaldıysa, atlayalım
          if (zonedTime.isBefore(tz.TZDateTime.now(tz.local))) {
            debugPrint('$i gün öncesi için bildirim zamanı geçmiş, atlanıyor');
            continue;
          }

          _scheduleExactNotification(uniqueId, title, body, zonedTime, type);
          debugPrint(
              '$i gün öncesi için bildirim planlandı: $notificationDay (ID: $uniqueId)');
        }
      }
    } catch (e) {
      debugPrint('Bildirim planlanırken hata oluştu: $e');
    }
  }

  // Bugün için bildirim planlamak için yardımcı metod
  Future<void> _scheduleNotificationForToday(int id, String title, String body,
      TimeOfDay notificationTime, String type) async {
    final now = DateTime.now();

    // Bugün için belirlenen saati ayarla
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    // Eğer belirlenen saat geçtiyse
    if (scheduledTime.isBefore(now)) {
      // O zaman şimdi + 5 saniye için hemen bildirim göster
      final immediate = now.add(const Duration(seconds: 5));
      final zonedTime = tz.TZDateTime.from(immediate, tz.local);
      _scheduleExactNotification(id, title, body, zonedTime, type);
      debugPrint(
          'Belirlenen saat geçtiği için bildirim 5 saniye sonra gösterilecek');
    } else {
      // Henüz vakit gelmemişse, belirlenen saate göre planla
      final zonedTime = tz.TZDateTime.from(scheduledTime, tz.local);
      _scheduleExactNotification(id, title, body, zonedTime, type);
      debugPrint(
          'Bugün için bildirim planlandı: ${scheduledTime.hour}:${scheduledTime.minute}');
    }
  }

  // Tam bir bildirim planlamak için yardımcı metod
  Future<void> _scheduleExactNotification(int id, String title, String body,
      tz.TZDateTime zonedTime, String type) async {
    try {
      // Önce planlanan bildirimi iptal et (varsa)
      await _notifications.cancel(id);

      // Sonra yeni bildirimi planla
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        zonedTime,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'payment_$id',
      );

      // Bir de yedek olarak, planlı tarihten biraz önce de anlık bildirim göndereceğiz
      // Bu, bazı cihazlarda alarmın çalışmaması durumunda yedek önlem
      final backupId = id + 10000; // Aynı ID çakışmasını önlemek için

      // Planlı bildirimden 1 dakika önce yedek bildirim
      final backupTime = zonedTime.subtract(const Duration(minutes: 1));

      // Yedek bildirimi de planlama
      if (backupTime.isAfter(tz.TZDateTime.now(tz.local))) {
        await _notifications.cancel(backupId);
        await _notifications.zonedSchedule(
          backupId,
          title,
          body,
          backupTime,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'backup_$id',
        );
        debugPrint(
            'Yedek bildirim başarıyla planlandı: $backupTime (ID: $backupId)');
      }

      debugPrint('Bildirim başarıyla planlandı: $zonedTime (ID: $id)');

      // Aynı zamanda Shared Preferences'a da planlanan bildirimleri kaydedelim
      final scheduledDateTime =
          DateTime.fromMillisecondsSinceEpoch(zonedTime.millisecondsSinceEpoch);
      _saveScheduledNotification(id, title, body, scheduledDateTime, type);
    } catch (e) {
      debugPrint('Bildirim planlanırken hata oluştu: $e');
    }
  }

  // Planlanan bildirimleri kaydetmek için
  Future<void> _saveScheduledNotification(int id, String title, String body,
      DateTime scheduledDate, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications =
          prefs.getStringList('scheduled_notifications') ?? [];

      // Bildirim bilgilerini JSON benzeri bir formatta saklayalım
      final notificationData =
          '$id|$title|$body|${scheduledDate.millisecondsSinceEpoch}|$type';

      // Aynı ID'ye sahip bir bildirim varsa, önce onu kaldıralım
      notifications.removeWhere((item) => item.startsWith('$id|'));

      // Yeni bildirimi ekleyelim
      notifications.add(notificationData);

      // Listeyi kaydedelim
      await prefs.setStringList('scheduled_notifications', notifications);
      debugPrint('Bildirim yerel olarak kaydedildi: $id');
    } catch (e) {
      debugPrint('Bildirim kaydedilirken hata: $e');
    }
  }

  // Kaydedilen bildirimleri yeniden planlamak için
  Future<void> rescheduleAllNotifications() async {
    try {
      debugPrint('Tüm bildirimler yeniden planlanıyor...');
      final prefs = await SharedPreferences.getInstance();
      final notifications =
          prefs.getStringList('scheduled_notifications') ?? [];

      if (notifications.isEmpty) {
        debugPrint('Kaydedilmiş bildirim bulunamadı');
        return;
      }

      // Tüm bildirimleri iptal edelim (temiz başlangıç)
      await _notifications.cancelAll();

      // Her bir bildirimi yeniden planlayalım
      for (final notificationData in notifications) {
        final parts = notificationData.split('|');
        if (parts.length < 5) continue;

        final id = int.tryParse(parts[0]) ?? 0;
        final title = parts[1];
        final body = parts[2];
        final scheduledDate =
            DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts[3]) ?? 0);
        final type = parts[4];

        // Sadece gelecekteki bildirimleri yeniden planla
        if (scheduledDate.isAfter(DateTime.now())) {
          await showNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            type: type,
            useCustomTime: true,
          );
        }
      }

      debugPrint('Bildirimler başarıyla yeniden planlandı');
    } catch (e) {
      debugPrint('Bildirimler yeniden planlanırken hata: $e');
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
    try {
      if (!_initialized) {
        await initialize();
      }

      final now = DateTime.now();
      await showNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: now.add(delay),
        type: type,
        useCustomTime: true,
      );
    } catch (e) {
      debugPrint('Test bildirimi gösterilirken hata: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

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
        payload: 'instant_$id',
      );
      debugPrint('Anlık bildirim başarıyla gönderildi (ID: $id)');
    } catch (e) {
      debugPrint('Anlık bildirim gönderilirken hata oluştu: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);

      // Kaydedilen bildirimleri de güncelleyelim
      final prefs = await SharedPreferences.getInstance();
      final notifications =
          prefs.getStringList('scheduled_notifications') ?? [];

      // Aynı ID'ye sahip bildirimi kaldıralım
      notifications.removeWhere((item) => item.startsWith('$id|'));

      // Güncellenmiş listeyi kaydedelim
      await prefs.setStringList('scheduled_notifications', notifications);

      debugPrint('Bildirim başarıyla iptal edildi: $id');
    } catch (e) {
      debugPrint('Bildirim iptal edilirken hata: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();

      // Kaydedilen bildirimleri de temizleyelim
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('scheduled_notifications', []);

      debugPrint('Tüm bildirimler başarıyla iptal edildi');
    } catch (e) {
      debugPrint('Tüm bildirimler iptal edilirken hata: $e');
    }
  }

  // Zamanlanmış bildirim testi için
  Future<void> testScheduledNotification() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      debugPrint('Bildirim testleri başlatılıyor...');

      // 1. Hemen gösterilecek bir bildirim
      await showInstantNotification(
        id: 9999,
        title: "Anlık Bildirim Testi",
        body: "Bu bir anlık bildirim testidir. Şimdi gösterilmelidir.",
      );

      // 2. 30 saniye sonra gösterilecek bir bildirim
      final halfMinuteLater = DateTime.now().add(const Duration(seconds: 30));
      await showNotification(
        id: 9998,
        title: "30 Saniye Sonra Bildirim",
        body:
            "Bu bildirim 30 saniye sonra gösterilmelidir: ${halfMinuteLater.hour}:${halfMinuteLater.minute}:${halfMinuteLater.second}",
        scheduledDate: halfMinuteLater,
        useCustomTime: true,
      );

      // 3. 1 dakika sonra gösterilecek bir bildirim
      final oneMinuteLater = DateTime.now().add(const Duration(minutes: 1));
      await showNotification(
        id: 9997,
        title: "1 Dakika Sonra Bildirim",
        body:
            "Bu bildirim 1 dakika sonra gösterilmelidir: ${oneMinuteLater.hour}:${oneMinuteLater.minute}:${oneMinuteLater.second}",
        scheduledDate: oneMinuteLater,
        useCustomTime: true,
      );

      // 4. Bugün için (1 gün önce) planlı bildirim testi
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await showNotification(
        id: 9996,
        title: "Yarın için Planlı Ödeme Bildirimi",
        body:
            "Bu bildirim yarın (${tomorrow.day}.${tomorrow.month}.${tomorrow.year}) için planlanmış bir ödeme bildirimini simüle eder. Bugün gösterilmelidir.",
        scheduledDate: tomorrow,
        type: 'payment',
      );

      debugPrint(
          "Test bildirimleri oluşturuldu: Anlık, 30 saniye sonra, 1 dakika sonra ve Yarın bildirimi");
    } catch (e) {
      debugPrint('Bildirim testleri çalıştırılırken hata: $e');
    }
  }
}
