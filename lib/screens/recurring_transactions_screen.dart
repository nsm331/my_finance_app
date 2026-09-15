import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../providers/category_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/icon_helper.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/category_picker_sheet.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  void _openAddOrEditRecurringSheet(BuildContext context, [RecurringTransactionModel? toEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditRecurringBottomSheet(recurringToEdit: toEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final recurringList = financeProvider.recurringTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('العمليات المجدولة والمتكررة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'فحص وتنفيذ العمليات المستحقة الآن',
            onPressed: () async {
              final count = await financeProvider.processDueRecurringTransactions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      count > 0
                          ? 'تم تسجيل $count عملية مستحقة جديدة بنجاح'
                          : 'لا توجد أي عمليات مجدولة مستحقة حالياً لهذا الشهر',
                    ),
                    backgroundColor: count > 0 ? AppColors.income : AppColors.primaryTeal,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: recurringList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_repeat_rounded,
                        size: 56,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'لا توجد عمليات مجدولة بعد',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يمكنك جدولة المصاريف أو الإيرادات الثابتة (مثل إيجار، اشتراك إنترنت، راتب شهري) ليتم تسجيلها تلقائياً كل شهر.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openAddOrEditRecurringSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة عملية مجدولة جديدة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: recurringList.length,
              itemBuilder: (context, index) {
                final item = recurringList[index];
                final isIncome = item.type == TransactionType.income;
                final amountColor = isIncome ? AppColors.income : AppColors.expense;
                final catColor = Color(item.categoryColorValue);

                return Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: item.isActive
                          ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          : Colors.grey.shade400.withValues(alpha: 0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _openAddOrEditRecurringSheet(context, item),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppIcons.getIcon(item.categoryIconCode),
                                  color: catColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        decoration: item.isActive ? null : TextDecoration.lineThrough,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.categoryName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'يوم ${item.dayOfMonth} من كل شهر',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryTeal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.formatWithSign(item.amount, item.currency, isIncome: isIncome),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: amountColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Switch.adaptive(
                                    value: item.isActive,
                                    activeThumbColor: AppColors.primaryTeal,
                                    onChanged: (val) {
                                      financeProvider.toggleRecurringActive(item.id, val);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.lastProcessedDate != null
                                    ? 'آخر تنفيذ: ${DateFormatter.formatDate(item.lastProcessedDate!)}'
                                    : 'لم يتم التنفيذ بعد',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 20),
                                tooltip: 'حذف العملية المجدولة',
                                onPressed: () async {
                                  final confirm = await ConfirmDialog.show(
                                    context,
                                    title: 'حذف العملية المجدولة',
                                    content: 'هل أنت متأكد من حذف هذه الجدولة؟ لن يتم تسجيلها تلقائياً بعد الآن.',
                                    confirmLabel: 'حذف',
                                    confirmColor: AppColors.expense,
                                  );
                                  if (confirm) {
                                    financeProvider.deleteRecurringTransaction(item.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddOrEditRecurringSheet(context),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('جدولة عملية جديدة'),
      ),
    );
  }
}

class _AddEditRecurringBottomSheet extends StatefulWidget {
  final RecurringTransactionModel? recurringToEdit;

  const _AddEditRecurringBottomSheet({this.recurringToEdit});

  @override
  State<_AddEditRecurringBottomSheet> createState() => _AddEditRecurringBottomSheetState();
}

class _AddEditRecurringBottomSheetState extends State<_AddEditRecurringBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late TransactionType _type;
  late AppCurrency _currency;
  CategoryModel? _selectedCategory;
  late int _dayOfMonth;

  bool get _isEditing => widget.recurringToEdit != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurringToEdit;
    _titleController = TextEditingController(text: r?.title ?? '');
    _amountController = TextEditingController(
      text: r != null ? (r.amount % 1 == 0 ? r.amount.toInt().toString() : r.amount.toString()) : '',
    );
    _notesController = TextEditingController(text: r?.notes ?? '');
    _type = r?.type ?? TransactionType.expense;
    _currency = r?.currency ?? AppCurrency.yer;
    _dayOfMonth = r?.dayOfMonth ?? DateTime.now().day;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catProvider = Provider.of<CategoryProvider>(context, listen: false);
      if (r != null) {
        _selectedCategory = catProvider.findById(r.categoryId);
      }
      if (_selectedCategory == null) {
        final list = _type == TransactionType.expense
            ? catProvider.expenseCategories
            : catProvider.incomeCategories;
        if (list.isNotEmpty) _selectedCategory = list.first;
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final catProvider = Provider.of<CategoryProvider>(context, listen: false);
    final categories = _type == TransactionType.expense
        ? catProvider.expenseCategories
        : catProvider.incomeCategories;
    final category = _selectedCategory ?? (categories.isNotEmpty ? categories.first : null);

    if (category == null) {
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

    if (_isEditing) {
      final updated = widget.recurringToEdit!.copyWith(
        title: _titleController.text.trim(),
        amount: amount,
        currency: _currency,
        type: _type,
        categoryId: category.id,
        categoryName: category.name,
        categoryIconCode: category.iconCode,
        categoryColorValue: category.colorValue,
        dayOfMonth: _dayOfMonth,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      financeProvider.updateRecurringTransaction(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعديل العملية المجدولة بنجاح'),
          backgroundColor: AppColors.income,
        ),
      );
    } else {
      final model = RecurringTransactionModel(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        amount: amount,
        currency: _currency,
        type: _type,
        categoryId: category.id,
        categoryName: category.name,
        categoryIconCode: category.iconCode,
        categoryColorValue: category.colorValue,
        dayOfMonth: _dayOfMonth,
        startDate: DateTime.now(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      financeProvider.addRecurringTransaction(model);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت جدولة العملية بنجاح! سيتم تسجيلها تلقائياً كل شهر.'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catProvider = Provider.of<CategoryProvider>(context);
    final categories = _type == TransactionType.expense
        ? catProvider.expenseCategories
        : catProvider.incomeCategories;
    final activeCat = _selectedCategory ?? (categories.isNotEmpty ? categories.first : null);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'تعديل العملية المجدولة' : 'جدولة عملية شهرية جديدة',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Income / Expense Toggle
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('مصروف دوري'),
                    icon: Icon(Icons.arrow_upward_rounded, color: AppColors.expense),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('دخل دوري'),
                    icon: Icon(Icons.arrow_downward_rounded, color: AppColors.income),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() {
                    _type = set.first;
                    final newCats = _type == TransactionType.expense
                        ? catProvider.expenseCategories
                        : catProvider.incomeCategories;
                    _selectedCategory = newCats.isNotEmpty ? newCats.first : null;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان العملية (مثال: إيجار الشقة) *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'أدخل عنواناً' : null,
              ),

              const SizedBox(height: 14),

              // Amount & Currency Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'المبلغ *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'أدخل المبلغ';
                        final n = double.tryParse(val.replaceAll(',', '').trim());
                        if (n == null || n <= 0) return 'مبلغ غير صحيح';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<AppCurrency>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: 'العملة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: AppCurrency.values.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c.code));
                      }).toList(),
                      onChanged: (c) {
                        if (c != null) setState(() => _currency = c);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Day of Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('يوم الاستحقاق الشهري:', style: TextStyle(fontWeight: FontWeight.w600)),
                  DropdownButton<int>(
                    value: _dayOfMonth,
                    borderRadius: BorderRadius.circular(12),
                    items: List.generate(31, (index) => index + 1).map((d) {
                      return DropdownMenuItem(
                        value: d,
                        child: Text('يوم $d من الشهر'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _dayOfMonth = val);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Category Picker
              InkWell(
                onTap: () async {
                  final picked = await CategoryPickerSheet.show(
                    context,
                    selectedCategoryId: activeCat?.id,
                    isExpense: _type == TransactionType.expense,
                  );
                  if (picked != null) {
                    setState(() => _selectedCategory = picked);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      if (activeCat != null) ...[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: activeCat.color.withValues(alpha: 0.2),
                          child: Icon(activeCat.iconData, size: 16, color: activeCat.color),
                        ),
                        const SizedBox(width: 10),
                        Text(activeCat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ] else
                        const Text('اختر التصنيف'),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isEditing ? 'حفظ التعديلات' : 'حفظ وجدولة العملية',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
