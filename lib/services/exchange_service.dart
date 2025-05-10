import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExchangeService {
  static final ExchangeService instance = ExchangeService._init();
  ExchangeService._init();

  static const String baseUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1';
  static const String fallbackUrl = 'https://latest.currency-api.pages.dev/v1';

  // Desteklenen para birimleri
  static final List<String> supportedCurrencies = [
    '₺', // Türk Lirası (TRY)
    '\$', // Amerikan Doları (USD)
    '€', // Euro (EUR)
    '£', // İngiliz Sterlini (GBP)
    '¥', // Japon Yeni (JPY)
  ];

  // Para birimi sembolünden kodu alma
  static String getCodeFromSymbol(String symbol) {
    switch (symbol) {
      case '₺':
        return 'try';
      case '\$':
        return 'usd';
      case '€':
        return 'eur';
      case '£':
        return 'gbp';
      case '¥':
        return 'jpy';
      default:
        return 'try';
    }
  }

  // Para birimi kodundan sembolü alma
  static String getSymbolFromCode(String code) {
    switch (code.toLowerCase()) {
      case 'try':
        return '₺';
      case 'usd':
        return '\$';
      case 'eur':
        return '€';
      case 'gbp':
        return '£';
      case 'jpy':
        return '¥';
      default:
        return '₺';
    }
  }

  // Seçilen baz para birimini kaydetme
  Future<void> saveBaseCurrency(String currencySymbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseCurrency', currencySymbol);
  }

  // Kaydedilen baz para birimini alma
  Future<String> getBaseCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('baseCurrency') ?? '₺'; // Varsayılan TL
  }

  // Döviz kurlarını alma
  Future<Map<String, dynamic>> getExchangeRates(
      String baseCurrencySymbol) async {
    try {
      final baseCurrency = getCodeFromSymbol(baseCurrencySymbol).toLowerCase();
      final url = '$baseUrl/currencies/$baseCurrency.json';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Bağlantı zaman aşımına uğradı'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[baseCurrency] ?? {};
      } else {
        // Ana URL başarısız olursa yedek URL'yi dene
        return _getFallbackExchangeRates(baseCurrency);
      }
    } catch (e) {
      print('Döviz kuru alınırken hata: $e');
      // Ana URL başarısız olursa yedek URL'yi dene
      return _getFallbackExchangeRates(getCodeFromSymbol(baseCurrencySymbol));
    }
  }

  // Yedek URL'den döviz kurlarını alma
  Future<Map<String, dynamic>> _getFallbackExchangeRates(
      String baseCurrency) async {
    try {
      final url = '$fallbackUrl/currencies/$baseCurrency.json';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Yedek bağlantı zaman aşımına uğradı'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[baseCurrency] ?? {};
      } else {
        throw Exception('Döviz kurları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('Yedek URL\'den döviz kuru alınırken hata: $e');
      return {}; // Boş harita döndür, bu durumda dönüşüm yapılmayacak
    }
  }

  // Para birimi dönüştürme
  Future<double> convertCurrency(
      double amount, String fromCurrencySymbol, String toCurrencySymbol) async {
    // Eğer para birimleri aynıysa dönüştürme yapmadan döndür
    if (fromCurrencySymbol == toCurrencySymbol) {
      return amount;
    }

    try {
      final fromCurrency = getCodeFromSymbol(fromCurrencySymbol).toLowerCase();
      final toCurrency = getCodeFromSymbol(toCurrencySymbol).toLowerCase();

      // Önce fromCurrency'nin kurlarını al
      final rates = await getExchangeRates(fromCurrencySymbol);

      if (rates.containsKey(toCurrency)) {
        return amount * (rates[toCurrency] as num);
      } else {
        throw Exception('Dönüştürme için kur bulunamadı');
      }
    } catch (e) {
      print('Para birimi dönüştürme hatası: $e');
      return amount; // Hata durumunda orijinal miktarı döndür
    }
  }

  // Tüm hesapları tek bir para birimine dönüştür
  Future<double> convertAllAccountsToBaseCurrency(
      List<Map<String, dynamic>> accounts, String baseCurrencySymbol) async {
    double totalAmount = 0.0;

    try {
      // Her hesap için para birimi dönüşümü yap
      for (var account in accounts) {
        final amount = account['balance'] as double;
        final currency = account['currency'] as String;

        final convertedAmount =
            await convertCurrency(amount, currency, baseCurrencySymbol);

        totalAmount += convertedAmount;
      }
    } catch (e) {
      print('Toplam hesap dönüştürme hatası: $e');
    }

    return totalAmount;
  }
}
