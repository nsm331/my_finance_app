import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import 'custom_text_field.dart';

class TransferSheet extends StatefulWidget {
  final int? initialFromWalletId;
  final int? initialToWalletId;
  final AppCurrency? initialCurrency;

  const TransferSheet({
    super.key,
    this.initialFromWalletId,
    this.initialToWalletId,
    this.initialCurrency,
  });

  static Future<bool?> show(
    BuildContext context, {
    int? initialFromWalletId,
    int? initialToWalletId,
    AppCurrency? initialCurrency,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransferSheet(
        initialFromWalletId: initialFromWalletId,
        initialToWalletId: initialToWalletId,
        initialCurrency: initialCurrency,
      ),
    );
  }

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  final _formKey = GlobalKey<FormState>();

  int? _fromWalletId;
  int? _toWalletId;
  late AppCurrency _selectedCurrency;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency ?? AppCurrency.yer;
    _amountController = TextEditingController();
    _noteController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
      final wallets = financeProvider.wallets;

      if (wallets.isNotEmpty) {
        setState(() {
          _fromWalletId = widget.initialFromWalletId ?? wallets.first.id;
          if (wallets.length > 1) {
            _toWalletId = widget.initialToWalletId ??
                wallets.firstWhere((w) => w.id != _fromWalletId, orElse: () => wallets.last).id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _swapWallets() {
    if (_fromWalletId != null && _toWalletId != null) {
      setState(() {
        final temp = _fromWalletId;
        _fromWalletId = _toWalletId;
        _toWalletId = temp;
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromWalletId == null || _toWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار المحفظة المصدر والمحفظة الهدف')),
      );
      return;
    }

    if (_fromWalletId == _toWalletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس المحفظة. اختر محفظة مختلفة.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من الصفر')),
      );
      return;
    }

    final financeProvider = Provider.of<FinanceProvider>(context, listen: false);

    // Check balance in source wallet for user awareness
    final sourceBalance = financeProvider.getWalletBalance(_fromWalletId!, _selectedCurrency);
    if (sourceBalance < amount) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.sarColor),
              SizedBox(width: 8),
              Text('تنبيه الرصيد', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'الرصيد المتوفر في المحفظة المصدر (${CurrencyFormatter.format(sourceBalance, _selectedCurrency)}) أقل من المبلغ المراد تحويله (${CurrencyFormatter.format(amount, _selectedCurrency)}).\n\nهل تود المتابعة على أية حال؟',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة التحويل', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      await financeProvider.transferFunds(
        fromWalletId: _fromWalletId!,
        toWalletId: _toWalletId!,
        amount: amount,
        currency: _selectedCurrency,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تم التحويل بنجاح (${CurrencyFormatter.format(amount, _selectedCurrency)}) 💸',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحويل: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final wallets = financeProvider.wallets;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: AppColors.primaryTeal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'تحويل بين المحافظ والحسابات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Wallets Selection Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // From Wallet
                    Expanded(
                      child: _buildWalletDropdown(
                        label: 'من محفظة',
                        value: _fromWalletId,
                        wallets: wallets,
                        onChanged: (id) => setState(() => _fromWalletId = id),
                        isDark: isDark,
                      ),
                    ),

                    // Swap Button
                    Padding(
                      padding: const EdgeInsets.only(top: 20, left: 6, right: 6),
                      child: IconButton.filledTonal(
                        onPressed: _swapWallets,
                        icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryTeal),
                        tooltip: 'تبديل المحافظ',
                      ),
                    ),

                    // To Wallet
                    Expanded(
                      child: _buildWalletDropdown(
                        label: 'إلى محفظة',
                        value: _toWalletId,
                        wallets: wallets,
                        onChanged: (id) => setState(() => _toWalletId = id),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Currency Selector Chips
                const Text(
                  'العملة المراد تحويلها',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: AppCurrency.values.map((cur) {
                    final isSelected = cur == _selectedCurrency;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCurrency = cur),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cur.primaryColor.withValues(alpha: 0.18)
                                  : (isDark ? AppColors.darkBackground : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? cur.primaryColor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  cur.symbol,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? cur.primaryColor : null,
                                  ),
                                ),
                                Text(
                                  cur.nameAr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? cur.primaryColor : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Amount Field
                CustomTextField(
                  controller: _amountController,
                  label: 'المبلغ المحول',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.payments_rounded,
                  suffix: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _selectedCurrency.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedCurrency.primaryColor,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'الرجاء إدخال المبلغ';
                    }
                    final n = double.tryParse(val.replaceAll(',', '').trim());
                    if (n == null || n <= 0) {
                      return 'أدخل مبلغاً صحيحاً أكبر من الصفر';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Notes Field
                CustomTextField(
                  controller: _noteController,
                  label: 'ملاحظة (اختياري)',
                  hint: 'مثلاً: تغذية المحفظة أو إيداع بنكي',
                  prefixIcon: Icons.notes_rounded,
                ),

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'تأكيد عملية التحويل',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletDropdown({
    required String label,
    required int? value,
    required List<WalletModel> wallets,
    required ValueChanged<int?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
              items: wallets.map((w) {
                return DropdownMenuItem<int>(
                  value: w.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: w.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(w.iconData, size: 15, color: w.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
