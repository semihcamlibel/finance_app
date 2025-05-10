import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  static ExchangeRateService get instance => _instance;

  ExchangeRateService._internal();

  // Dönüşüm için mevcut kurların önbelleği
  Map<String, double> _exchangeRates = {};
  DateTime? _lastUpdated;

  // API endpointi - Ücretsiz bir API kullanıyoruz
  final String _apiUrl = 'https://api.exchangerate-api.com/v4/latest/';

  // Cache'in süresi (6 saat)
  final Duration _cacheExpiration = const Duration(hours: 6);

  // Kurların önbelleğe alınıp alınmadığını ve güncel olup olmadığını kontrol eder
  bool get isRatesCached =>
      _exchangeRates.isNotEmpty &&
      _lastUpdated != null &&
      DateTime.now().difference(_lastUpdated!) < _cacheExpiration;

  // Önbelleğe almak ve yüklemek için para birimi sembolleri
  final List<String> _supportedCurrencies = ['₺', '\$', '€', '£', '¥'];

  // API ve SharedPreferences için para birimi kodları
  final Map<String, String> _currencyCodes = {
    '₺': 'TRY',
    '\$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY',
  };

  // Servis başlatıldığında önbellekteki kurları yükle
  Future<void> initialize() async {
    await _loadCachedRates();
  }

  // SharedPreferences'a kaydedilen kurları yükler
  Future<void> _loadCachedRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratesJson = prefs.getString('exchange_rates');
      final lastUpdatedMillis = prefs.getInt('exchange_rates_updated');

      if (ratesJson != null && lastUpdatedMillis != null) {
        _exchangeRates = Map<String, double>.from(json.decode(ratesJson));
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis);

        debugPrint(
            'Döviz kurları önbellekten yüklendi. Son güncelleme: ${_lastUpdated?.toIso8601String()}');
      } else {
        debugPrint('Önbellekte döviz kuru bulunamadı');
      }
    } catch (e) {
      debugPrint('Döviz kurları yüklenirken hata oluştu: $e');
    }
  }

  // Kurları API'den getirir ve önbelleğe kaydeder
  Future<void> fetchExchangeRates(String baseCurrency) async {
    try {
      // Para birimi sembolünü API'nin tanıdığı koda çevir
      final baseCode = _currencyCodes[baseCurrency] ?? 'TRY';

      debugPrint('Döviz kurları $baseCode için güncelleniyor...');

      final response = await http.get(Uri.parse('$_apiUrl$baseCode'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        // Kurları temizle ve yenilerini ekle
        _exchangeRates.clear();

        // Sadece desteklenen para birimlerini ekle
        _supportedCurrencies.forEach((currencySymbol) {
          final code = _currencyCodes[currencySymbol] ?? '';
          if (code.isNotEmpty && rates.containsKey(code)) {
            _exchangeRates[currencySymbol] = rates[code].toDouble();
          }
        });

        _lastUpdated = DateTime.now();

        // Kurları SharedPreferences'a kaydet
        await _cacheRates();

        debugPrint('Döviz kurları başarıyla güncellendi: $_exchangeRates');
      } else {
        debugPrint(
            'API yanıt vermedi: ${response.statusCode} - ${response.body}');
        throw Exception('API yanıt vermedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Döviz kurları güncellenirken hata oluştu: $e');
      // Hata durumunda önbellekteki eski verileri kullan, eğer yoksa hatayı tekrar yükselt
      if (_exchangeRates.isEmpty) {
        rethrow;
      }
    }
  }

  // Kurları SharedPreferences'a kaydeder
  Future<void> _cacheRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exchange_rates', json.encode(_exchangeRates));
      await prefs.setInt(
          'exchange_rates_updated', _lastUpdated!.millisecondsSinceEpoch);
      debugPrint('Döviz kurları önbelleğe kaydedildi');
    } catch (e) {
      debugPrint('Döviz kurları önbelleğe kaydedilirken hata oluştu: $e');
    }
  }

  // Belirli bir miktarı bir para biriminden diğerine çevirir
  double convertCurrency(
      double amount, String fromCurrency, String toCurrency) {
    // Aynı para birimi ise doğrudan miktarı döndür
    if (fromCurrency == toCurrency) return amount;

    // Eğer kurlar boş ise veya güncel değilse, hata mesajı ver ama işlemi engelleme
    if (_exchangeRates.isEmpty) {
      debugPrint('HATA: Döviz kurları henüz yüklenmemiş');
      return amount; // En azından orijinal değeri döndür
    }

    // fromCurrency ve toCurrency için kurları al
    final fromRate = _exchangeRates[fromCurrency] ?? 1.0;
    final toRate = _exchangeRates[toCurrency] ?? 1.0;

    // Dönüşümü yap ve sonucu döndür
    return (amount / fromRate) * toRate;
  }

  // Para birimini formatla
  static String formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(
      locale: currency == '₺'
          ? 'tr_TR'
          : (currency == '€' ? 'de_DE' : (currency == '£' ? 'en_GB' : 'en_US')),
      symbol: currency,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  // Mevcut kurları göster (debug amaçlı)
  String getRatesDebugInfo() {
    if (_exchangeRates.isEmpty) return 'Kurlar henüz yüklenmedi';
    final sb = StringBuffer();
    sb.write('Son güncelleme: ${_lastUpdated?.toIso8601String()}\n');
    _exchangeRates.forEach((key, value) {
      sb.write('$key = $value\n');
    });
    return sb.toString();
  }
}
