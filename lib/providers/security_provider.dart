import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityProvider extends ChangeNotifier {
  final SecurityService _securityService;

  bool _isLocked = false;
  bool _isPinSet = false;
  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricSupported = false;
  bool _isAuthenticating = false;
  DateTime? _lastSuccessfulAuthTime;
  String? _lastAuthError;

  SecurityProvider({SecurityService? securityService})
      : _securityService = securityService ?? SecurityService() {
    _init();
  }

  bool get isLocked => _isLocked;
  bool get isPinSet => _isPinSet;
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isBiometricSupported => _isBiometricSupported;
  bool get isAuthenticating => _isAuthenticating;
  bool get recentlyAuthenticated {
    if (_lastSuccessfulAuthTime == null) return false;
    return DateTime.now().difference(_lastSuccessfulAuthTime!).inMilliseconds < 2500;
  }
  String? get lastAuthError => _lastAuthError;

  Future<void> _init() async {
    _isPinSet = _securityService.isPinSet();
    _isAppLockEnabled = _securityService.isAppLockEnabled();
    _isBiometricEnabled = _securityService.isBiometricEnabled();
    _isBiometricSupported = await _securityService.isDeviceBiometricSupported();

    // If PIN is enabled, app starts in locked state
    _isLocked = _isPinSet && _isAppLockEnabled;
    notifyListeners();
  }

  /// Refresh biometric hardware and enrollment status
  Future<bool> checkBiometricSupport() async {
    _isBiometricSupported = await _securityService.isDeviceBiometricSupported();
    notifyListeners();
    return _isBiometricSupported;
  }

  /// Verify whether entered PIN matches the stored PIN
  bool verifyPin(String pin) {
    return _securityService.verifyPin(pin);
  }

  /// Verify entered PIN and unlock if valid
  bool unlockWithPin(String pin) {
    final isValid = _securityService.verifyPin(pin);
    if (isValid) {
      _isLocked = false;
      _lastAuthError = null;
      _lastSuccessfulAuthTime = DateTime.now();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Unlock directly via successful Biometric verification
  void unlockWithBiometrics() {
    _isLocked = false;
    _lastAuthError = null;
    _lastSuccessfulAuthTime = DateTime.now();
    notifyListeners();
  }

  /// Trigger Biometric Authentication Prompt
  Future<bool> authenticateWithBiometrics() async {
    if (_isAuthenticating || recentlyAuthenticated) return false;
    _isAuthenticating = true;
    _lastAuthError = null;
    try {
      final result = await _securityService.authenticateWithBiometricsDetails();
      if (result.success) {
        unlockWithBiometrics();
        return true;
      } else {
        _lastAuthError = result.errorMessage;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastAuthError = 'حدث خطأ أثناء المصادقة: $e';
      notifyListeners();
      return false;
    } finally {
      // حزام الأمان: استخدام Future.delayed يضمن أن النظام استقر في حالة resumed واختفت نافذة البصمة قبل إعادة تفعيل المراقبة
      await Future.delayed(const Duration(milliseconds: 600));
      _isAuthenticating = false;
    }
  }

  /// Lock app manually (e.g. from background or settings)
  void lockApp() {
    if (_isAuthenticating || recentlyAuthenticated) return; // حماية إضافية تمنع القفل أثناء أو فور انتهاء المصادقة
    if (_isPinSet && _isAppLockEnabled) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Set new PIN
  Future<void> setPin(String pin) async {
    await _securityService.setPin(pin);
    _isPinSet = true;
    _isAppLockEnabled = true;
    _isLocked = false;
    notifyListeners();
  }

  /// Enable or disable app lock
  Future<void> toggleAppLock(bool enabled) async {
    await _securityService.setAppLockEnabled(enabled);
    _isAppLockEnabled = enabled;
    if (!enabled) {
      _isLocked = false;
      _isBiometricEnabled = false;
      await _securityService.setBiometricEnabled(false);
    }
    notifyListeners();
  }

  /// Enable or disable biometric lock
  Future<void> toggleBiometric(bool enabled) async {
    await _securityService.setBiometricEnabled(enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  /// Remove PIN entirely
  Future<void> removePin() async {
    await _securityService.removePin();
    _isPinSet = false;
    _isAppLockEnabled = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }
}
