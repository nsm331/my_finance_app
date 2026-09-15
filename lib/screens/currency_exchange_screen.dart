import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';

class CurrencyExchangeScreen extends StatefulWidget {
  final AppCurrency? initialFromCurrency;
  final AppCurrency? initialToCurrency;

  const CurrencyExchangeScreen({
    super.key,
    this.initialFromCurrency,
    this.initialToCurrency,
  });

  @override
  State<CurrencyExchangeScreen> createState() => _CurrencyExchangeScreenState();
}

class _CurrencyExchangeScreenState extends State<CurrencyExchangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _notesController = TextEditingController();

  late AppCurrency _fromCurrency;
  late AppCurrency _toCurrency;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fromCurrency = widget.initialFromCurrency ?? AppCurrency.sar;
    _toCurrency = widget.initialToCurrency ?? AppCurrency.yer;
    if (_fromCurrency == _toCurrency) {
      _toCurrency = _fromCurrency == AppCurrency.yer ? AppCurrency.sar : AppCurrency.yer;
    }
    _setInitialDefaultRate();
  }

  bool get _isMultiplication {
    if (_fromCurrency != AppCurrency.yer && _toCurrency == AppCurrency.yer) {
      return true; // Foreign (SAR/USD) -> YER: Multiply
    }
    if (_fromCurrency == AppCurrency.yer && _toCurrency != AppCurrency.yer) {
      return false; // YER -> Foreign (SAR/USD): Divide
    }
    if (_fromCurrency == AppCurrency.usd && _toCurrency == AppCurrency.sar) {
      return true; // USD -> SAR: Multiply
    }
    if (_fromCurrency == AppCurrency.sar && _toCurrency == AppCurrency.usd) {
      return false; // SAR -> USD: Divide
    }
    return true;
  }

  void _setInitialDefaultRate() {
    // Default rate: 410 for SAR, 1600 for USD, 3.75 for USD/SAR
    if ((_fromCurrency == AppCurrency.sar && _toCurrency == AppCurrency.yer) ||
        (_fromCurrency == AppCurrency.yer && _toCurrency == AppCurrency.sar)) {
      _rateController.text = '410';
    } else if ((_fromCurrency == AppCurrency.usd && _toCurrency == AppCurrency.yer) ||
        (_fromCurrency == AppCurrency.yer && _toCurrency == AppCurrency.usd)) {
      _rateController.text = '1600';
    } else if ((_fromCurrency == AppCurrency.usd && _toCurrency == AppCurrency.sar) ||
        (_fromCurrency == AppCurrency.sar && _toCurrency == AppCurrency.usd)) {
      _rateController.text = '3.75';
    } else {
      _rateController.text = '1.0';
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _setInitialDefaultRate();
    });
  }

  double get _calculatedToAmount {
    final fromAmount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '').trim()) ?? 0.0;
    if (fromAmount <= 0 || rate <= 0) return 0.0;
    return _isMultiplication ? (fromAmount * rate) : (fromAmount / rate);
  }

  String get _formulaText {
    final fromAmountText = _amountController.text.isNotEmpty ? _amountController.text : "0";
    final rateText = _rateController.text.isNotEmpty ? _rateController.text : "0";
    final op = _isMultiplication ? '×' : '÷';
    return 'المعادلة: $fromAmountText ${_fromCurrency.symbol} $op $rateText = ${CurrencyFormatter.formatAmount(_calculatedToAmount)} ${_toCurrency.symbol}';
  }

  Future<void> _submitExchange() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromCurrency == _toCurrency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار عملتين مختلفتين للتحويل'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final fromAmount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final rate = double.tryParse(_rateController.text.replaceAll(',', '').trim()) ?? 0.0;

    if (fromAmount <= 0 || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ وسعر صرف صحيحين'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final financeProvider = Provider.of<FinanceProvider>(context, listen: false);

      await financeProvider.executeCurrencyTransfer(
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
        fromAmount: fromAmount,
        exchangeRate: rate,
        customToAmount: _calculatedToAmount,
        date: _selectedDate,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم التحويل بنجاح: خصم ${CurrencyFormatter.formatWithCurrency(fromAmount, _fromCurrency)} وإضافة ${CurrencyFormatter.formatWithCurrency(_calculatedToAmount, _toCurrency)}',
            ),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تنفيذ الصرافة: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final fromBalance = financeProvider.getTotalBalance(_fromCurrency);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحويل والصرافة بين العملات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange_rounded, color: AppColors.primaryTeal, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سيتم خصم المبلغ من رصيد العملة الأولى وإضافة المبلغ المحسوب إلى رصيد العملة الثانية فوراً في سجل العمليات.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Currencies Selection Card with Swap
              Card(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // From Currency Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تحويل من (العملة المسحوب منها):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الرصيد: ${CurrencyFormatter.formatWithCurrency(fromBalance, _fromCurrency)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: fromBalance >= 0 ? AppColors.income : AppColors.expense,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<AppCurrency>(
                            value: _fromCurrency,
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(12),
                            items: AppCurrency.values.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Icon(c.icon, size: 16, color: c.primaryColor),
                                    const SizedBox(width: 6),
                                    Text(c.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (c) {
                              if (c != null && c != _fromCurrency) {
                                setState(() {
                                  _fromCurrency = c;
                                  if (_toCurrency == _fromCurrency) {
                                    _toCurrency = AppCurrency.values.firstWhere((x) => x != _fromCurrency);
                                  }
                                  _setInitialDefaultRate();
                                });
                              }
                            },
                          ),
                        ],
                      ),

                      // Swap Button Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.swap_vert_rounded, size: 22),
                              tooltip: 'عكس العملات',
                              onPressed: _swapCurrencies,
                            ),
                            Expanded(child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                          ],
                        ),
                      ),

                      // To Currency Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'إلى (العملة المستلمة):',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<AppCurrency>(
                            value: _toCurrency,
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(12),
                            items: AppCurrency.values.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Icon(c.icon, size: 16, color: c.primaryColor),
                                    const SizedBox(width: 6),
                                    Text(c.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (c) {
                              if (c != null && c != _toCurrency) {
                                setState(() {
                                  _toCurrency = c;
                                  if (_fromCurrency == _toCurrency) {
                                    _fromCurrency = AppCurrency.values.firstWhere((x) => x != _toCurrency);
                                  }
                                  _setInitialDefaultRate();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Source Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد تحويله (${_fromCurrency.symbol}) *',
                  hintText: 'مثال: 100',
                  prefixIcon: Icon(_fromCurrency.icon, color: _fromCurrency.primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'يرجى إدخال المبلغ';
                  final numVal = double.tryParse(val);
                  if (numVal == null || numVal <= 0) return 'أدخل رقماً صحيحاً وموجباً';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Exchange Rate Field
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: (_fromCurrency == AppCurrency.sar || _toCurrency == AppCurrency.sar)
                      ? 'سعر صرف الريال السعودي (الافتراضي: 410) *'
                      : 'سعر الصرف المعتمد *',
                  hintText: 'سعر 1 ${_fromCurrency.symbol} بـ ${_toCurrency.symbol}',
                  prefixIcon: const Icon(Icons.price_change_outlined, color: AppColors.primaryTeal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'يرجى إدخال سعر الصرف';
                  final numVal = double.tryParse(val);
                  if (numVal == null || numVal <= 0) return 'أدخل سعر صرف صحيح';
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Live Calculation Output Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المبلغ المحسوب للإيداع:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          CurrencyFormatter.formatWithCurrency(_calculatedToAmount, _toCurrency),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formulaText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primaryTeal),
                      const SizedBox(width: 12),
                      Text(
                        'تاريخ العملية: ${DateFormatter.formatDate(_selectedDate)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية (اختياري)',
                  hintText: 'اسم الصراف، سبب التحويل...',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitExchange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'تأكيد وحفظ الصرافة والتحويل',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
