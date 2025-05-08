import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({super.key});

  DateTime _getNextSpecificTime(TimeOfDay time) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Eğer belirtilen saat bugün için geçmişse, yarına planla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Testi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                // Yarın için bir ödeme bildirimi planla
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                NotificationService.instance.showNotification(
                  id: 5,
                  title: 'Yaklaşan Ödeme Bildirimi',
                  body: 'Yarın için planlanmış bir ödemeniz var.',
                  scheduledDate: tomorrow,
                  type: 'payment',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ödeme bildirimi planlandı: Şu tarih için: ${tomorrow.day}.${tomorrow.month}.${tomorrow.year}',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Yarın için Ödeme Bildirimi Planla'),
            ),
            const SizedBox(height: 16),
            // Yeni test butonu: Tam 1 gün sonrası için planlama
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final now = DateTime.now();
                // Bugünün aynı saati ama yarın için (1 gün sonrası)
                final tomorrow = DateTime(
                  now.year,
                  now.month,
                  now.day + 1,
                  now.hour,
                  now.minute + 1, // Şu andan 1 dakika sonra
                );

                NotificationService.instance.showNotification(
                  id: 6001,
                  title: 'TAM 1 GÜN SONRA BİLDİRİM TESTİ',
                  body:
                      'Bu bildirim ${tomorrow.day}.${tomorrow.month}.${tomorrow.year} tarihinde ${tomorrow.hour}:${tomorrow.minute} saatinde gösterilecek',
                  scheduledDate: tomorrow,
                  type: 'payment',
                  useCustomTime: true, // Tam belirtilen zamanda göster
                );

                // Aynı zamanda 1 gün geri sayımlı bir bildirim (bildirim ayarlarında "1 gün önce" seçili olmalı)
                NotificationService.instance.showNotification(
                  id: 6002,
                  title: 'BİLDİRİM AYARI TESTİ (1 gün)',
                  body:
                      'Bu bildirim ayarlarda "1 gün önce" seçili ise şimdi gösterilmeli, yoksa gösterilmeyecek.',
                  scheduledDate: tomorrow,
                  type: 'payment',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'İki bildirim planlandı:\n1. Tam yarın - ${tomorrow.hour}:${tomorrow.minute} için\n2. Ayarlarda seçili zaman için (1 gün önce olmalı)',
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('TAM 1 GÜN SONRA ÖZELLEŞTİRİLMİŞ TEST'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                NotificationService.instance.showInstantNotification(
                  id: 1,
                  title: 'Anlık Gelir Bildirimi',
                  body: 'Bu bir anlık gelir bildirimi testidir.',
                  type: 'income',
                );
              },
              child: const Text('Anlık Gelir Bildirimi'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                NotificationService.instance.showTestNotification(
                  id: 2,
                  title: '10 Saniye Sonra Bildirim',
                  body: 'Bu bir test bildirimidir.',
                  delay: const Duration(seconds: 10),
                  type: 'payment',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('10 saniye sonra bildirim alacaksınız'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('10 Saniye Sonra Test Bildirimi'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                NotificationService.instance.showTestNotification(
                  id: 3,
                  title: '1 Dakika Sonra Bildirim',
                  body: 'Bu bir test bildirimidir.',
                  delay: const Duration(minutes: 1),
                  type: 'income',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('1 dakika sonra bildirim alacaksınız'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('1 Dakika Sonra Test Bildirimi'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                NotificationService.instance.showInstantNotification(
                  id: 4,
                  title: 'Bütçe Aşımı Uyarısı',
                  body: 'Alışveriş kategorisinde bütçe aşımı tespit edildi.',
                  type: 'budget',
                );
              },
              child: const Text('Anlık Bütçe Aşımı Bildirimi'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                NotificationService.instance.cancelAllNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tüm bildirimler iptal edildi'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Tüm Bildirimleri İptal Et'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                // Yeni test metodunu çağırıyoruz
                NotificationService.instance.testScheduledNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Üç farklı bildirim testi başlatıldı!'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Tüm Bildirim Testlerini Çalıştır'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // 5 gün sonrası için bir ödeme planla
                final now = DateTime.now();
                final futureDate = DateTime(
                  now.year,
                  now.month,
                  now.day + 5, // 5 gün sonra
                  10, // Saat 10:00'da
                  0,
                );

                NotificationService.instance.showNotification(
                  id: 7000,
                  title: '5 GÜN SONRA ÖDEME',
                  body:
                      'Bu bildirim, ayarlarda seçili her gün için gösterilecek şekilde planlandı.',
                  scheduledDate: futureDate,
                  type: 'payment',
                  // useCustomTime: false varsayılanı kullanılıyor,
                  // böylece ayarlardaki gün sayısına göre bildirimler oluşturulacak
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '5 gün sonrası (${futureDate.day}.${futureDate.month}) için ödeme bildirimi planlandı.\n'
                      'Ayarlarda seçtiğiniz gün sayısına göre her gün bildirim alacaksınız.',
                    ),
                    duration: const Duration(seconds: 5),
                  ),
                );
              },
              child: const Text('ÇOK GÜNLÜ BİLDİRİM TESTİ (5 GÜN SONRA)'),
            ),
            const SizedBox(height: 16),
            // Yeni "Senaryo testi" butonu - özellikle çoklu gün bildirimleri için
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Kullanıcı ayarlarını alma
                final prefs = await SharedPreferences.getInstance();
                final hour = prefs.getInt('notificationTimeHour') ?? 9;
                final minute = prefs.getInt('notificationTimeMinute') ?? 0;
                final daysBefore = prefs.getInt('notificationDaysBefore') ?? 3;

                // Ayın 11'i için ödeme oluşturma (Örnek senaryo)
                final now = DateTime.now();

                // Bugünden 3 gün sonra için ödeme planla
                final targetDay = now.day + 3;
                final paymentDate = DateTime(
                  now.year,
                  now.month,
                  targetDay, // şu andan 3 gün sonra
                );

                // Bildirim oluştur
                NotificationService.instance.showNotification(
                  id: 9000,
                  title: 'ÖZEL SENARYO TESTİ',
                  body: 'Bu bildirim, ayarlarınıza göre her gün gösterilecek: '
                      'Hedef: ${paymentDate.day}.${paymentDate.month}.${paymentDate.year}, '
                      'Ayar: $daysBefore gün önce, Saat: $hour:$minute',
                  scheduledDate: paymentDate,
                  type: 'payment',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'ÖZEL SENARYO TEST EDİLİYOR:\n'
                      '✓ Ayarlarınız: $daysBefore gün önce, Saat: $hour:$minute\n'
                      '✓ Hedef Tarih: ${paymentDate.day}.${paymentDate.month}.${paymentDate.year}\n'
                      '✓ Bugünün Tarihi: ${now.day}.${now.month}.${now.year}\n'
                      '✓ Kalan Gün: ${paymentDate.difference(DateTime(now.year, now.month, now.day)).inDays} gün\n\n'
                      'Ayarlarınıza göre ${daysBefore} gün boyunca her gün bildirim almalısınız!',
                    ),
                    duration: const Duration(seconds: 8),
                  ),
                );
              },
              child: const Text('ÖZEL SENARYO TESTİ (3 GÜN SONRASI)'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
