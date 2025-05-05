import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;
  final LocalAuthentication _auth = LocalAuthentication();

  AuthService._();

  Future<bool> isAuthenticationRequired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('requireAuthenticationOnStart') ?? false;
  }

  Future<bool> authenticate() async {
    try {
      final isAuthenticationRequired = await this.isAuthenticationRequired();
      if (!isAuthenticationRequired) return true;

      final canAuthenticate =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) return true;

      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return true;

      return await _auth.authenticate(
        localizedReason: 'Uygulamaya erişmek için kimlik doğrulama gerekli',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      print('Kimlik doğrulama hatası: $e');
      return false;
    }
  }
}
