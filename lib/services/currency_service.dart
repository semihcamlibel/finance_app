import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class CurrencyService {
  static final CurrencyService instance = CurrencyService._init();

  // Para birimi kurları - canlı API bağlantısı yapılana kadar sabit değerler
  Map<String, double> _rates = {
    '₺': 1.0, // Temel birim TL
    '\$': 33.0, // 1 Dolar = 33 TL
    '€': 35.0, // 1 Euro = 35 TL
    '£': 42.0, // 1 Pound = 42 TL
    '¥': 0.23, // 1 Yen = 0.23 TL
  };

  DateTime _lastUpdated = DateTime.now();
  static const int updateThresholdMinutes = 60; // Saatte bir güncelle

  CurrencyService._init();

  Future<void> initializeRates() async {
    // Kaydedilmiş kurları oku
    await _loadSavedRates();

    // Son güncellemenin üzerinden belirtilen süre geçtiyse kurları güncelle
    if (DateTime.now().difference(_lastUpdated).inMinutes >
        updateThresholdMinutes) {
      await updateRates();
    }
  }

  Future<void> _loadSavedRates() async {
    final prefs = await SharedPreferences.getInstance();

    // Kaydedilmiş kurları oku
    final ratesJson = prefs.getString('currency_rates');
    if (ratesJson != null) {
      final ratesMap = jsonDecode(ratesJson) as Map<String, dynamic>;
      _rates = ratesMap.map((key, value) => MapEntry(key, value.toDouble()));

      // Son güncelleme zamanını oku
      final lastUpdatedString = prefs.getString('currency_rates_updated');
      if (lastUpdatedString != null) {
        _lastUpdated = DateTime.parse(lastUpdatedString);
      }
    }
  }

  Future<void> updateRates() async {
    try {
      // Gerçek API entegrasyonu için burası değiştirilecek
      // Şu an için manuel olarak güncelleme yapıyoruz
      // Örnek bir API: https://exchangeratesapi.io/
      final response = await http.get(
        Uri.parse('https://api.exchangerate.host/latest?base=TRY'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        // Kurları güncelleyerek TL bazında tutacağız (1 birim = kaç TL)
        _rates['₺'] = 1.0;
        _rates['\$'] = 1 / rates['USD'];
        _rates['€'] = 1 / rates['EUR'];
        _rates['£'] = 1 / rates['GBP'];
        _rates['¥'] = 1 / rates['JPY'];

        // Güncelleme zamanını kaydet
        _lastUpdated = DateTime.now();

        // Kurları ve güncelleme zamanını kaydet
        await _saveRates();

        debugPrint('Kurlar başarıyla güncellendi: $_rates');
      } else {
        debugPrint('Kur bilgisi güncellenemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Kur bilgisi güncellenirken hata oluştu: $e');
      // Hata durumunda mevcut kurları kullanmaya devam et
    }
  }

  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_rates', jsonEncode(_rates));
    await prefs.setString(
        'currency_rates_updated', _lastUpdated.toIso8601String());
  }

  // Bir para biriminden diğerine dönüşüm yap
  double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;

    // Önce TL'ye çevir, sonra hedef para birimine çevir
    final amountInTL = amount * _rates[fromCurrency]!;
    return amountInTL / _rates[toCurrency]!;
  }

  // Bir hesabın bakiyesini seçilen para birimine dönüştür
  double convertAccountBalance(
      double balance, String accountCurrency, String targetCurrency) {
    return convert(balance, accountCurrency, targetCurrency);
  }

  // Birden fazla hesabın toplam bakiyesini seçilen para birimine dönüştür
  double convertTotalBalance(
      List<Map<String, dynamic>> accounts, String targetCurrency) {
    double total = 0;

    for (var account in accounts) {
      final double balance = account['balance'];
      final String currency = account['currency'];
      total += convert(balance, currency, targetCurrency);
    }

    return total;
  }

  // Mevcut döviz kurlarını döndür
  Map<String, double> get currentRates => _rates;

  // Son güncelleme zamanını döndür
  DateTime get lastUpdated => _lastUpdated;
}
