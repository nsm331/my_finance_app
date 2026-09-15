import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/category_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/currency_selector_widget.dart';
import '../widgets/category_picker_sheet.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_formatter.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final AppCurrency? initialCurrency;
  final bool? initialIsExpense;

  const AddEditTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.initialCurrency,
    this.initialIsExpense,
  });

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late bool _isExpense;
  late AppCurrency _currency;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  CategoryModel? _selectedCategory;
  int? _selectedWalletId;
  late DateTime _selectedDate;
  bool _isRecurringMonthly = false;

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transactionToEdit;

    _isExpense = t != null
        ? (t.type == TransactionType.expense)
        : (widget.initialIsExpense ?? true);
    _currency = t?.currency ?? widget.initialCurrency ?? AppCurrency.yer;
    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController = TextEditingController(
      text: t != null ? (t.amount % 1 == 0 ? t.amount.toInt().toString() : t.amount.toString()) : '',
    );
    _notesController = TextEditingController(text: t?.notes ?? '');
    _selectedDate = t?.date ?? DateTime.now();
    _selectedWalletId = t?.walletId;

    // Init category and default wallet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final financeProvider = Provider.of<FinanceProvider>(context, listen: false);

      if (t != null) {
        _selectedCategory = categoryProvider.findById(t.categoryId);
      }
      if (_selectedCategory == null) {
        final list = _isExpense
            ? categoryProvider.expenseCategories
            : categoryProvider.incomeCategories;
        if (list.isNotEmpty) {
          _selectedCategory = list.first;
        }
      }

      if (_selectedWalletId == null && financeProvider.wallets.isNotEmpty) {
        _selectedWalletId = financeProvider.wallets.first.id;
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _openCategoryPicker() {
    CategoryPickerSheet.show(
      context,
      selectedCategoryId: _selectedCategory?.id,
      isExpense: _isExpense,
    ).then((cat) {
      if (cat != null) {
        setState(() {
          _selectedCategory = cat;
        });
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار التصنيف')),
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
    final id = _isEditing ? widget.transactionToEdit!.id : const Uuid().v4();

    final newTransaction = TransactionModel(
      id: id,
      title: _titleController.text.trim(),
      amount: amount,
      currency: _currency,
      type: _isExpense ? TransactionType.expense : TransactionType.income,
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name,
      categoryIconCode: _selectedCategory!.iconCode,
      categoryColorValue: _selectedCategory!.colorValue,
      date: _selectedDate,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: _isEditing ? widget.transactionToEdit!.createdAt : DateTime.now(),
      isRecurring: _isRecurringMonthly,
      walletId: _selectedWalletId ?? (financeProvider.wallets.isNotEmpty ? financeProvider.wallets.first.id : 1),
      isTransfer: widget.transactionToEdit?.isTransfer ?? 0,
      transferId: widget.transactionToEdit?.transferId,
      exchangeRate: widget.transactionToEdit?.exchangeRate,
      targetCurrency: widget.transactionToEdit?.targetCurrency,
      targetAmount: widget.transactionToEdit?.targetAmount,
    );

    if (_isEditing) {
      await financeProvider.updateTransaction(newTransaction);
    } else {
      await financeProvider.addTransaction(newTransaction);
      if (_isRecurringMonthly) {
        final recurringModel = RecurringTransactionModel(
          id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
          title: _titleController.text.trim(),
          amount: amount,
          currency: _currency,
          type: _isExpense ? TransactionType.expense : TransactionType.income,
          categoryId: _selectedCategory!.id,
          categoryName: _selectedCategory!.name,
          categoryIconCode: _selectedCategory!.iconCode,
          categoryColorValue: _selectedCategory!.colorValue,
          dayOfMonth: _selectedDate.day,
          startDate: _selectedDate,
          lastProcessedDate: _selectedDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await financeProvider.addRecurringTransaction(recurringModel);
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = _isExpense ? AppColors.expense : AppColors.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل العملية' : 'إضافة عملية جديدة'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // Type Toggle (مصروف / دخل)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isExpense) {
                            setState(() {
                              _isExpense = true;
                              // Switch default category to expense
                              final cats = Provider.of<CategoryProvider>(context, listen: false).expenseCategories;
                              if (cats.isNotEmpty) _selectedCategory = cats.first;
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isExpense ? AppColors.expense : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isExpense
                                ? [
                                    BoxShadow(
                                      color: AppColors.expense.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'مصروف (-)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isExpense
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isExpense) {
                            setState(() {
                              _isExpense = false;
                              // Switch default category to income
                              final cats = Provider.of<CategoryProvider>(context, listen: false).incomeCategories;
                              if (cats.isNotEmpty) _selectedCategory = cats.first;
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isExpense ? AppColors.income : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isExpense
                                ? [
                                    BoxShadow(
                                      color: AppColors.income.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'دخل (+)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: !_isExpense
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Currency Selector
              const Text(
                'العملة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              CurrencySelectorWidget(
                selectedCurrency: _currency,
                onCurrencyChanged: (cur) {
                  setState(() {
                    _currency = cur;
                  });
                },
              ),

              const SizedBox(height: 18),

              // Amount Input
              CustomTextField(
                controller: _amountController,
                label: 'المبلغ',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.attach_money_rounded,
                suffix: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _currency.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currency.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  final n = double.tryParse(val.replaceAll(',', '').trim());
                  if (n == null || n <= 0) {
                    return 'أدخل مبلغاً صالحاً أكبر من الصفر';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Title / Description Input
              CustomTextField(
                controller: _titleController,
                label: 'الوصف / العنوان',
                hint: _isExpense ? 'مثال: شراء أغراض البقالة' : 'مثال: راتب الشهر',
                prefixIcon: Icons.edit_note_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال وصف العملية';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Category Picker Tile
              const Text(
                'التصنيف',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _openCategoryPicker,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedCategory != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedCategory!.color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedCategory!.iconData,
                            color: _selectedCategory!.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedCategory!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.category_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Text(
                          'اختر التصنيف',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Wallet Selector Tile
              Consumer<FinanceProvider>(
                builder: (context, financeProvider, _) {
                  final wallets = financeProvider.wallets;
                  if (wallets.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المحفظة / الحساب المالي',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedWalletId ?? (wallets.isNotEmpty ? wallets.first.id : null),
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
                                      child: Icon(
                                        w.iconData,
                                        size: 16,
                                        color: w.color,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      w.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() => _selectedWalletId = id);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  );
                },
              ),

              // Date Picker Tile
              const Text(
                'التاريخ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primaryTeal),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatFullDate(_selectedDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Notes Input
              CustomTextField(
                controller: _notesController,
                label: 'ملاحظات إضافية (اختياري)',
                hint: 'أي تفاصيل أخرى تود تذكرها...',
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),

              const SizedBox(height: 18),

              // Recurring Monthly Toggle (Only for new transactions)
              if (!_isEditing)
                Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _isRecurringMonthly
                          ? AppColors.primaryTeal.withValues(alpha: 0.5)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'تكرار هذه العملية شهرياً (عملية دورية)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _isRecurringMonthly
                          ? 'سيتم تسجيلها تلقائياً يوم ${_selectedDate.day} من كل شهر'
                          : 'تفعيل الجدولة التلقائية شهرياً (مثل إيجار أو اشتراك)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isRecurringMonthly
                            ? AppColors.primaryTeal
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    secondary: const Icon(Icons.event_repeat_rounded, color: AppColors.primaryTeal),
                    value: _isRecurringMonthly,
                    activeThumbColor: AppColors.primaryTeal,
                    onChanged: (val) {
                      setState(() => _isRecurringMonthly = val);
                    },
                  ),
                ),

              const SizedBox(height: 28),

              // Save Button
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isEditing ? 'حفظ التعديلات' : 'إضافة العملية',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
