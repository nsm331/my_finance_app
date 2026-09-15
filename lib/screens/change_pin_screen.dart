import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../widgets/pin_keyboard_widget.dart';
import '../core/constants/app_colors.dart';

/// 3-Step PIN Change State Machine
enum PinChangeState {
  enterOld,
  enterNew,
  confirmNew,
}

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  PinChangeState _currentState = PinChangeState.enterOld;
  String _enteredPin = '';
  String _tempNewPin = '';
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // If no PIN was set yet, begin directly at entering new PIN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final securityProvider = Provider.of<SecurityProvider>(context, listen: false);
      if (!securityProvider.isPinSet) {
        setState(() {
          _currentState = PinChangeState.enterNew;
        });
      }
    });
  }

  void _onKeyPressed(String digit) {
    if (_isSubmitting) return;

    if (_enteredPin.length < 4) {
      setState(() {
        _errorMessage = null;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _handlePinSubmitted();
      }
    }
  }

  void _onDelete() {
    if (_isSubmitting) return;

    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handlePinSubmitted() async {
    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    switch (_currentState) {
      // Step 1: Validate old PIN against stored hash
      case PinChangeState.enterOld:
        final isValid = securityProvider.verifyPin(_enteredPin);
        if (isValid) {
          setState(() {
            _currentState = PinChangeState.enterNew;
            _enteredPin = '';
            _errorMessage = null;
          });
        } else {
          setState(() {
            _errorMessage = 'رمز المرور الحالي غير صحيح';
            _enteredPin = '';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('رمز المرور الحالي غير صحيح، حاول مرة أخرى'),
                backgroundColor: AppColors.expense,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        break;

      // Step 2: Store temporary new PIN and prompt confirmation
      case PinChangeState.enterNew:
        setState(() {
          _tempNewPin = _enteredPin;
          _enteredPin = '';
          _errorMessage = null;
          _currentState = PinChangeState.confirmNew;
        });
        break;

      // Step 3: Confirm new PIN, save via SecurityProvider if matched
      case PinChangeState.confirmNew:
        if (_enteredPin == _tempNewPin) {
          setState(() => _isSubmitting = true);
          try {
            await securityProvider.setPin(_tempNewPin);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تغيير رمز المرور بنجاح!'),
                  backgroundColor: AppColors.income,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.pop(context, true);
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isSubmitting = false;
                _errorMessage = 'حدث خطأ أثناء حفظ الرمز: $e';
              });
            }
          }
        } else {
          setState(() {
            _errorMessage = 'الرمزان غير متطابقين، أعد إدخال الرمز الجديد';
            _enteredPin = '';
            _tempNewPin = '';
            _currentState = PinChangeState.enterNew;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الرمزان غير متطابقين! يرجى إعادة إدخال الرمز الجديد للتأكيد'),
                backgroundColor: AppColors.expense,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        break;
    }
  }

  String get _titleText {
    switch (_currentState) {
      case PinChangeState.enterOld:
        return 'أدخل الرمز الحالي';
      case PinChangeState.enterNew:
        return 'أدخل الرمز الجديد';
      case PinChangeState.confirmNew:
        return 'تأكيد الرمز الجديد';
    }
  }

  String get _subtitleText {
    switch (_currentState) {
      case PinChangeState.enterOld:
        return 'يرجى إدخال رمز PIN الحالي للتحقق من هويتك';
      case PinChangeState.enterNew:
        return 'أدخل 4 أرقام جديدة لا يسهل تخمينها';
      case PinChangeState.confirmNew:
        return 'أعد إدخال الرمز الجديد للتأكيد والمطابقة';
    }
  }

  IconData get _stateIcon {
    switch (_currentState) {
      case PinChangeState.enterOld:
        return Icons.lock_outline_rounded;
      case PinChangeState.enterNew:
        return Icons.password_rounded;
      case PinChangeState.confirmNew:
        return Icons.check_circle_outline_rounded;
    }
  }

  Widget _buildStepIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = [
      {'label': 'الحالي', 'state': PinChangeState.enterOld},
      {'label': 'الجديد', 'state': PinChangeState.enterNew},
      {'label': 'التأكيد', 'state': PinChangeState.confirmNew},
    ];

    int currentIndex = _currentState.index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isCompleted = index < currentIndex;
        final isActive = index == currentIndex;

        return Row(
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.income
                        : (isActive ? AppColors.primaryTeal : (isDark ? AppColors.darkCard : Colors.grey.shade200)),
                    border: Border.all(
                      color: isActive
                          ? AppColors.primaryTeal
                          : (isCompleted ? AppColors.income : Colors.grey.shade400),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index]['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? AppColors.primaryTeal
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ],
            ),
            if (index < steps.length - 1)
              Container(
                width: 36,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                color: index < currentIndex
                    ? AppColors.income
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('تغيير رمز المرور (PIN)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // 3-Step visual progress
              _buildStepIndicator(context),

              const Spacer(flex: 1),

              // Icon with badge
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _stateIcon,
                  color: AppColors.primaryTeal,
                  size: 38,
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Title & Subtitle
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey<PinChangeState>(_currentState),
                  children: [
                    Text(
                      _titleText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // PIN dots & keyboard widget
              if (_isSubmitting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                )
              else
                PinKeyboardWidget(
                  pin: _enteredPin,
                  errorText: _errorMessage,
                  onKeyPressed: _onKeyPressed,
                  onDelete: _onDelete,
                  showBiometric: false,
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
