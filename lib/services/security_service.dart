import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'hive_db_service.dart';

class SecurityService {
  static const String _keyPinHash = 'user_pin_hash';
  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyBiometricEnabled = 'biometric_lock_enabled';

  final HiveDbService _dbService;
  final LocalAuthentication _localAuth;

  SecurityService({
    HiveDbService? dbService,
    LocalAuthentication? localAuth,
  })  : _dbService = dbService ?? HiveDbService(),
        _localAuth = localAuth ?? LocalAuthentication();

  /// Hash a string using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode('finance_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  /// Check if a PIN is set
  bool isPinSet() {
    final hash = _dbService.getSetting(_keyPinHash);
    return hash != null && hash.toString().isNotEmpty;
  }

  /// Check if App Lock is enabled
  bool isAppLockEnabled() {
    if (!isPinSet()) return false;
    return _dbService.getSetting(_keyAppLockEnabled, defaultValue: true) as bool;
  }

  /// Check if Biometric Lock is enabled in settings
  bool isBiometricEnabled() {
    if (!isPinSet()) return false;
    return _dbService.getSetting(_keyBiometricEnabled, defaultValue: false) as bool;
  }

  /// Verify entered PIN against stored hash
  bool verifyPin(String enteredPin) {
    final storedHash = _dbService.getSetting(_keyPinHash);
    if (storedHash == null) return true;
    return _hashPin(enteredPin) == storedHash.toString();
  }

  /// Set or update PIN
  Future<void> setPin(String newPin) async {
    final hash = _hashPin(newPin);
    await _dbService.setSetting(_keyPinHash, hash);
    await _dbService.setSetting(_keyAppLockEnabled, true);
  }

  /// Toggle App Lock enabled state
  Future<void> setAppLockEnabled(bool enabled) async {
    await _dbService.setSetting(_keyAppLockEnabled, enabled);
  }

  /// Toggle Biometric Lock enabled state
  Future<void> setBiometricEnabled(bool enabled) async {
    await _dbService.setSetting(_keyBiometricEnabled, enabled);
  }

  /// Remove PIN and disable lock
  Future<void> removePin() async {
    await _dbService.removeSetting(_keyPinHash);
    await _dbService.setSetting(_keyAppLockEnabled, false);
    await _dbService.setSetting(_keyBiometricEnabled, false);
  }

  /// Check if device supports hardware biometrics and has enrolled biometrics
  Future<bool> isDeviceBiometricSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      debugPrint('[SecurityService] isSupported: $isSupported, canCheck: $canCheck, available: $availableBiometrics');
      return isSupported && (canCheck || availableBiometrics.isNotEmpty);
    } catch (e) {
      debugPrint('[SecurityService] Error checking biometric support: $e');
      return false;
    }
  }

  /// Get list of available biometrics on device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[SecurityService] Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate user via Biometrics (Fingerprint / Face)
  /// Returns a record with `success` and optional `errorMessage`
  Future<({bool success, String? errorMessage})> authenticateWithBiometricsDetails() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        debugPrint('[SecurityService] Device does not support biometrics');
        return (success: false, errorMessage: 'الجهاز لا يدعم المصادقة بالبصمة');
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (!canCheck && availableBiometrics.isEmpty) {
        debugPrint('[SecurityService] No biometrics enrolled or hardware unavailable');
        return (success: false, errorMessage: 'لم يتم تسجيل أي بصمة في إعدادات الهاتف');
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: 'يرجى تأكيد البصمة للوصول إلى بياناتك المالية في ميزانيتي',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'المصادقة بالبصمة',
            biometricHint: 'المس مستشعر البصمة للمتابعة',
            cancelButton: 'إلغاء واستخدام الرمز',
            biometricRequiredTitle: 'البصمة مطلوبة',
            goToSettingsButton: 'الإعدادات',
            goToSettingsDescription: 'يرجى إعداد البصمة في إعدادات الهاتف',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      return (
        success: didAuth,
        errorMessage: didAuth ? null : 'تم إلغاء المصادقة أو لم يتم التعرف على البصمة',
      );
    } on PlatformException catch (e) {
      debugPrint('[SecurityService] Biometric PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      String userMessage = 'فشلت المصادقة بالبصمة';
      switch (e.code) {
        case 'NotAvailable':
          userMessage = 'مستشعر البصمة غير متوفر حالياً على جهازك';
          break;
        case 'NotEnrolled':
          userMessage = 'لا توجد بصمة مسجلة في إعدادات الهاتف';
          break;
        case 'LockedOut':
          userMessage = 'تم قفل البصمة مؤقتاً لكثرة المحاولات، يرجى استخدام رمز PIN';
          break;
        case 'PermanentlyLockedOut':
          userMessage = 'تم قفل البصمة بشكل دائم، يرجى فتح الهاتف بكلمة المرور أولاً';
          break;
        case 'PasscodeNotSet':
          userMessage = 'يرجى تفعيل قفل الشاشة والبصمة في الهاتف أولاً';
          break;
        default:
          if (e.message != null && e.message!.isNotEmpty) {
            userMessage = 'خطأ بالبصمة: ${e.message}';
          }
      }
      return (success: false, errorMessage: userMessage);
    } catch (e) {
      debugPrint('[SecurityService] Biometric general exception: $e');
      return (success: false, errorMessage: 'حدث خطأ أثناء المصادقة بالبصمة: $e');
    }
  }

  /// Authenticate user via Biometrics (Fingerprint / Face)
  Future<bool> authenticateWithBiometrics() async {
    final result = await authenticateWithBiometricsDetails();
    return result.success;
  }
}
