import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../widgets/pin_keyboard_widget.dart';
import '../core/constants/app_colors.dart';

enum PinScreenMode {
  unlock,
  setupNew,
  confirmNew,
}

class PinLockScreen extends StatefulWidget {
  final PinScreenMode mode;
  final String? initialNewPin; // For confirmation step
  final VoidCallback? onSuccess;

  const PinLockScreen({
    super.key,
    this.mode = PinScreenMode.unlock,
    this.initialNewPin,
    this.onSuccess,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  String _tempPin = '';
  late PinScreenMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    if (widget.initialNewPin != null) {
      _tempPin = widget.initialNewPin!;
    }

    // Auto-prompt biometrics if enabled and in unlock mode
    if (_currentMode == PinScreenMode.unlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndTriggerBiometric();
      });
    }
  }

  Future<void> _checkAndTriggerBiometric() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
    if (securityProvider.recentlyAuthenticated || securityProvider.isAuthenticating) return;
    if (securityProvider.isBiometricEnabled && securityProvider.isBiometricSupported) {
      final success = await securityProvider.authenticateWithBiometrics();
      if (success && mounted) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
      } else if (mounted && securityProvider.lastAuthError != null) {
        setState(() {
          _errorMessage = securityProvider.lastAuthError;
        });
      }
    }
  }

  void _onKeyPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = null;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handlePinComplete() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    switch (_currentMode) {
      case PinScreenMode.unlock:
        final isValid = securityProvider.unlockWithPin(_enteredPin);
        if (isValid) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          }
        } else {
          setState(() {
            _errorMessage = 'رمز المرور غير صحيح، حاول مرة أخرى';
            _enteredPin = '';
          });
        }
        break;

      case PinScreenMode.setupNew:
        setState(() {
          _tempPin = _enteredPin;
          _enteredPin = '';
          _currentMode = PinScreenMode.confirmNew;
        });
        break;

      case PinScreenMode.confirmNew:
        if (_enteredPin == _tempPin) {
          await securityProvider.setPin(_enteredPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تعيين رمز الأمان بنجاح'),
                backgroundColor: AppColors.income,
              ),
            );
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else {
              Navigator.pop(context, true);
            }
          }
        } else {
          setState(() {
            _errorMessage = 'الرمزان غير متطابقين، أعد المحاولة';
            _enteredPin = '';
            _currentMode = PinScreenMode.setupNew;
          });
        }
        break;
    }
  }

  String get _titleText {
    switch (_currentMode) {
      case PinScreenMode.unlock:
        return 'تطبيق ميزانيتي';
      case PinScreenMode.setupNew:
        return 'تعيين رمز مرور جديد';
      case PinScreenMode.confirmNew:
        return 'تأكيد رمز المرور';
    }
  }

  String get _subtitleText {
    switch (_currentMode) {
      case PinScreenMode.unlock:
        return 'الرجاء إدخال رمز الأمان أو استخدام البصمة للمتابعة';
      case PinScreenMode.setupNew:
        return 'أدخل 4 أرقام لحماية بياناتك المالية';
      case PinScreenMode.confirmNew:
        return 'أعد إدخال الرمز للتأكيد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final securityProvider = Provider.of<SecurityProvider>(context);

    return PopScope(
      canPop: _currentMode != PinScreenMode.unlock,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: _currentMode != PinScreenMode.unlock
            ? AppBar(
                title: Text(_currentMode == PinScreenMode.setupNew ? 'رمز أمان جديد' : 'تأكيد الرمز'),
                backgroundColor: Colors.transparent,
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.primaryTeal,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 20),

                // Title & Subtitle
                Text(
                  _titleText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),

                const Spacer(flex: 1),

                // PIN Dots & Keypad
                PinKeyboardWidget(
                  pin: _enteredPin,
                  errorText: _errorMessage,
                  onKeyPressed: _onKeyPressed,
                  onDelete: _onDelete,
                  showBiometric: _currentMode == PinScreenMode.unlock &&
                      securityProvider.isBiometricEnabled &&
                      securityProvider.isBiometricSupported,
                  onBiometricPressed: _checkAndTriggerBiometric,
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
