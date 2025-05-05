import 'package:flutter/material.dart';
import '../services/notification_service.dart';

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
                  const SnackBar(
                    content: Text(
                      'Ödeme bildirimi planlandı: Ayarlarda belirlenen saatte bildirim alacaksınız',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('Yarın için Ödeme Bildirimi Planla'),
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
          ],
        ),
      ),
    );
  }
}
