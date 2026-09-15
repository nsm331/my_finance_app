import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class PinKeyboardWidget extends StatelessWidget {
  final String pin;
  final int pinLength;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onDelete;
  final VoidCallback? onBiometricPressed;
  final bool showBiometric;
  final String? errorText;

  const PinKeyboardWidget({
    super.key,
    required this.pin,
    this.pinLength = 4,
    required this.onKeyPressed,
    required this.onDelete,
    this.onBiometricPressed,
    this.showBiometric = false,
    this.errorText,
  });

  Widget _buildDot(bool isFilled, bool isError) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? (isError ? AppColors.expense : AppColors.primaryTeal)
            : Colors.transparent,
        border: Border.all(
          color: isError
              ? AppColors.expense
              : (isFilled ? AppColors.primaryTeal : Colors.grey.shade400),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String value, {Widget? customWidget, VoidCallback? customAction}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: customAction ?? () => onKeyPressed(value),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: customWidget ??
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null && errorText!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pinLength,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildDot(index < pin.length, isError),
            ),
          ),
        ),

        if (isError) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.expense,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Keypad Grid
        Column(
          children: [
            Row(
              children: [
                _buildKey(context, '1'),
                _buildKey(context, '2'),
                _buildKey(context, '3'),
              ],
            ),
            Row(
              children: [
                _buildKey(context, '4'),
                _buildKey(context, '5'),
                _buildKey(context, '6'),
              ],
            ),
            Row(
              children: [
                _buildKey(context, '7'),
                _buildKey(context, '8'),
                _buildKey(context, '9'),
              ],
            ),
            Row(
              children: [
                if (showBiometric && onBiometricPressed != null)
                  _buildKey(
                    context,
                    '',
                    customWidget: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.primaryTeal,
                      size: 30,
                    ),
                    customAction: onBiometricPressed,
                  )
                else
                  const Spacer(),
                _buildKey(context, '0'),
                _buildKey(
                  context,
                  '',
                  customWidget: const Icon(Icons.backspace_outlined, size: 22),
                  customAction: onDelete,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
