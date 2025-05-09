import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF3D5AFE);
  static const Color accentColor = Color(0xFF536DFE);
  static const Color successColor = Color(0xFF66BB6A);
  static const Color errorColor = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color incomeColor = Color(0xFF4CAF50);
  static const Color expenseColor = Color(0xFFF44336);
  static const Color debtColor = Color(0xFFFF9800);
  static const Color creditColor = Color(0xFF03A9F4);
  static const Color greyColor = Color(0xFF9E9E9E);
  static const Color lightGreyColor = Color(0xFFEEEEEE);
  static const Color darkGreyColor = Color(0xFF424242);

  // Para birimi sembolü
  static const String currencySymbol = '₺';

  // Tema renk seçenekleri
  static List<Color> colorOptions = [
    Color(0xFF2196F3), // Mavi
    Color(0xFF9C27B0), // Mor
    Color(0xFF4CAF50), // Yeşil
    Color(0xFFF44336), // Kırmızı
    Color(0xFFFF9800), // Turuncu
    Color(0xFF795548), // Kahverengi
    Color(0xFF009688), // Turkuaz
    Color(0xFF607D8B), // Mavi Gri
    Color(0xFFE91E63), // Pembe
    Color(0xFFFFEB3B), // Sarı
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: greyColor.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: greyColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: greyColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: darkGreyColor,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: darkGreyColor,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: darkGreyColor,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: darkGreyColor,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: darkGreyColor,
        ),
        titleSmall: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: darkGreyColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: darkGreyColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: darkGreyColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: greyColor,
        ),
      ),
    );
  }

  // Özel stil yardımcıları
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          spreadRadius: 1,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Giriş-çıkış (gelir-gider) için stil belirleyen metod
  static Color getAmountColor(double amount) {
    return amount >= 0 ? incomeColor : expenseColor;
  }

  // Bildirim kategorilerine göre renk seçimi
  static Color getNotificationColor(String type) {
    switch (type) {
      case 'payment':
        return expenseColor;
      case 'income':
        return incomeColor;
      case 'budget':
        return warningColor;
      default:
        return primaryColor;
    }
  }

  // Öncelik seviyelerine göre renk seçimi
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'yüksek':
      case 'high':
        return errorColor;
      case 'orta':
      case 'medium':
        return warningColor;
      case 'düşük':
      case 'low':
        return successColor;
      default:
        return greyColor;
    }
  }
}
