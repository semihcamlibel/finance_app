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

      // Sadece tarihleri kullanarak (saat olmadan) gün farkını hesaplayalım
      final today = DateTime(now.year, now.month, now.day);
      final targetDate =
          DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
      final daysUntilTarget = targetDate.difference(today).inDays;

      debugPrint(
          'HEDEF TARİH: $targetDate, BUGÜN: $today, KALAN GÜN: $daysUntilTarget, BİLDİRİM GÜNÜ: $daysBefore gün önce');

      // Özel test zamanlı bildirim mi yoksa normal ayarlanmış bildirim mi?
      if (useCustomTime) {
        // Test bildirimleri için özel zaman kullan
        final zonedTime = tz.TZDateTime.from(scheduledDate, tz.local);

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
        // Normal bildirim mantığı: Birden çok gün bildirim göndermek için

        // Eğer tarih, bildirim gün sayısı içindeyse bildirimler gönderilsin
        // Örnek: Hedef tarih 3 gün sonra, ve kullanıcı 3 gün önce bildirim istemiş
        // Bu durumda bildirimler şu günlerde gönderilmeli: Bugün (3 gün kala), Yarın (2 gün kala), 2 gün sonra (1 gün kala)

        debugPrint(
            'Normal bildirim planlanıyor. daysUntilTarget = $daysUntilTarget, daysBefore = $daysBefore');

        // Eğer hedef tarih, şu andan daysBefore gün veya daha az ilerideyse
        // bugünden başlayarak her gün bildirim göstermeliyiz
        if (daysUntilTarget <= daysBefore) {
          // Bugünden başlayarak, hedef güne kadar her gün bildirim göster
          // 0 = bugün, 1 = yarın, 2 = 2 gün sonra... şeklinde
          for (int dayOffset = 0; dayOffset <= daysUntilTarget; dayOffset++) {
            // O gün için bildirimi planla
            final notificationDay = today.add(Duration(days: dayOffset));

            // Her gün için benzersiz ID oluştur
            final uniqueId = id + (dayOffset * 1000);

            // O gün ve kullanıcının seçtiği saat için bildirimi planla
            final notificationDateTime = DateTime(
              notificationDay.year,
              notificationDay.month,
              notificationDay.day,
              notificationTime.hour,
              notificationTime.minute,
            );

            final zonedTime =
                tz.TZDateTime.from(notificationDateTime, tz.local);

            // Eğer belirlenen saat geçmişse ve bugüne ait bir bildirimse
            if (dayOffset == 0 &&
                zonedTime.isBefore(tz.TZDateTime.now(tz.local))) {
              // 5 saniye sonraya planla
              debugPrint(
                  'Bugünkü bildirim için saat geçmiş, 5 saniye sonra gösterilecek');
              final immediateTime =
                  tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
              _scheduleExactNotification(
                  uniqueId, title, body, immediateTime, type);
            } else {
              _scheduleExactNotification(
                  uniqueId, title, body, zonedTime, type);
              debugPrint(
                  'Bildirim planlandı: ${daysUntilTarget - dayOffset} gün kala - '
                  'Tarih: ${notificationDay.day}.${notificationDay.month}.${notificationDay.year} '
                  'Saat: ${notificationTime.hour}:${notificationTime.minute} (ID: $uniqueId)');
            }
          }
        } else {
          // Hedef tarih daysBefore günden daha uzak ise, bildirimleri daha sonra göstereceğiz
          // Bu durumda şimdilik sadece hafızaya kaydedelim
          debugPrint(
              'Hedef tarih $daysUntilTarget gün sonra. Bildirim günlerinden ($daysBefore) daha uzak, şimdilik kaydediliyor.');

          // Yine de bildirimin kaydını tutalım
          final scheduledDateTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            notificationTime.hour,
            notificationTime.minute,
          );

          _saveScheduledNotification(id, title, body, scheduledDateTime, type);
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

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final notificationTime = await _getNotificationTime();
      final daysBefore = await _getNotificationDaysBefore();

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

        // Hedef tarihin sadece gün/ay/yıl kısmını kullan
        final targetDate = DateTime(
            scheduledDate.year, scheduledDate.month, scheduledDate.day);

        // Hedef tarih bugünden sonra ise bildirimleri yeniden planlayalım
        if (targetDate.isAfter(today) || targetDate.isAtSameMomentAs(today)) {
          // Gün farkını hesapla
          final daysUntilTarget = targetDate.difference(today).inDays;

          debugPrint(
              'Eski bildirimi yeniden planlama: ID=$id, Hedef=$targetDate, Kalan=$daysUntilTarget gün');

          // Eğer hedef tarih, bildirim gün sayısı içindeyse bildirimleri oluştur
          if (daysUntilTarget <= daysBefore) {
            // Bugünden başlayarak, hedef güne kadar (dahil) her gün bildirim planla
            for (int dayOffset = 0; dayOffset <= daysUntilTarget; dayOffset++) {
              final notificationDay = today.add(Duration(days: dayOffset));
              final uniqueId = id + (dayOffset * 1000);

              final notificationDateTime = DateTime(
                notificationDay.year,
                notificationDay.month,
                notificationDay.day,
                notificationTime.hour,
                notificationTime.minute,
              );

              final zonedTime =
                  tz.TZDateTime.from(notificationDateTime, tz.local);

              // Bugün için ve saat geçtiyse, 5 saniye sonraya planla
              if (dayOffset == 0 &&
                  zonedTime.isBefore(tz.TZDateTime.now(tz.local))) {
                final immediateTime =
                    tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
                _scheduleExactNotification(
                    uniqueId, title, body, immediateTime, type);

                debugPrint(
                    'Geçmiş saatli bugünkü bildirim hemen planlandı: ID=$uniqueId');
              } else {
                _scheduleExactNotification(
                    uniqueId, title, body, zonedTime, type);

                debugPrint('Yeniden planlanan bildirim: ID=$uniqueId, '
                    '${daysUntilTarget - dayOffset} gün kala (${notificationDay.day}.${notificationDay.month})');
              }
            }
          } else {
            // Henüz bildirim zamanı gelmemiş, tekrar kaydet
            _saveScheduledNotification(id, title, body, scheduledDate, type);
            debugPrint(
                'Hedef tarih ($daysUntilTarget gün) bildirim zamanından uzak, tekrar kaydedildi.');
          }
        } else {
          debugPrint(
              'Geçmiş tarihli bildirim atlandı: ID=$id, Tarih=$scheduledDate');
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

      // 4. Ayarlardaki günlük bildirim testi
      final now = DateTime.now();
      final daysBefore = await _getNotificationDaysBefore();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Yarın için bildirim planla, kullanıcının gün ayarlarına göre
      await showNotification(
        id: 9996,
        title: "AYARLARA GÖRE BİLDİRİM TESTİ",
        body:
            "Bu bildirim yarın (${tomorrow.day}.${tomorrow.month}) için bir ödeme bildirimidir. "
            "Eğer ayarlarda $daysBefore gün seçtiyseniz ve bugün gösteriliyorsa, sistem doğru çalışıyor.",
        scheduledDate: tomorrow,
        type: 'payment',
        // useCustomTime false olduğu için kullanıcının ayarlarına göre bildirim zamanlanır
      );

      // 5. Özel olarak tam 3 gün sonra için bildirim - belirlenen gün sayısına göre test
      final threeDaysLater = DateTime(now.year, now.month, now.day + 3);
      await showNotification(
        id: 9995,
        title: "3 GÜN SONRA İÇİN BİLDİRİM",
        body: "Bu bildirim 3 gün sonra olan bir ödeme için test. "
            "Ayarlarda seçilen gün sayısına göre her gün tekrarlayacak şekilde planlandı.",
        scheduledDate: threeDaysLater,
        type: 'payment',
      );

      debugPrint("Test bildirimleri oluşturuldu:\n"
          "1. Anlık bildirim\n"
          "2. 30 saniye sonra bildirim\n"
          "3. 1 dakika sonra bildirim\n"
          "4. Yarın için bildirim (ayarlara göre bugün gösterilir veya gösterilmez)\n"
          "5. 3 gün sonra için bildirim (ayarlara göre her gün bildirim gösterilir)");
    } catch (e) {
      debugPrint('Bildirim testleri çalıştırılırken hata: $e');
    }
  }
}
