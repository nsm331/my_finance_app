import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/app_currency.dart';
import '../providers/category_provider.dart';
import '../providers/finance_provider.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/currency_selector_widget.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/confirm_dialog.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/icon_helper.dart';
import '../services/pdf_report_service.dart';
import 'category_details_screen.dart';

class CategoriesBudgetScreen extends StatefulWidget {
  final bool isEmbedded;

  const CategoriesBudgetScreen({super.key, this.isEmbedded = false});

  @override
  State<CategoriesBudgetScreen> createState() => _CategoriesBudgetScreenState();
}

class _CategoriesBudgetScreenState extends State<CategoriesBudgetScreen> {
  AppCurrency _selectedCurrency = AppCurrency.yer;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  void _navigateToCategoryDetails(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailsScreen(
          category: category,
          selectedMonth: _selectedMonth,
          initialCurrency: _selectedCurrency,
        ),
      ),
    );
  }

  Future<void> _exportMonthlyPdf() async {
    final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final monthName = DateFormatter.formatMonthYear(_selectedMonth);
    final filename = 'التقرير_المالي_الشهري_${_selectedMonth.year}_${_selectedMonth.month}.pdf';

    await PdfReportService.showReportModal(
      context,
      title: 'التقرير المالي الشهري ($monthName)',
      filename: filename,
      onGenerateBytes: () => PdfReportService.generateMonthlyReportBytes(
        month: _selectedMonth,
        allTransactions: financeProvider.transactions,
        categories: categoryProvider.categories,
        currency: _selectedCurrency,
      ),
    );
  }

  static const List<IconData> _availableIcons = AppIcons.availableCategoryIcons;

  static const List<int> _availableColors = [
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF10B981, // Emerald
    0xFF0D9488, // Teal
    0xFF3B82F6, // Blue
    0xFF6366F1, // Indigo
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFF64748B, // Slate
  ];

  Future<void> _showSetBudgetDialog(CategoryModel category) async {
    final currentBudget = category.getBudgetForCurrency(_selectedCurrency);
    final controller = TextEditingController(
      text: currentBudget > 0 ? (currentBudget % 1 == 0 ? currentBudget.toInt().toString() : currentBudget.toString()) : '',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(category.iconData, color: category.color),
            const SizedBox(width: 8),
            Text('سقف ميزانية: ${category.name}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حدد الحد الأقصى للمصروفات الشهرية بالـ (${_selectedCurrency.nameAr}):',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: controller,
              label: 'سقف الميزانية الشهري',
              hint: '0.00 (اتركه فارغاً لإلغاء السقف)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.speed_rounded,
              suffix: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _selectedCurrency.symbol,
                  style: TextStyle(fontWeight: FontWeight.bold, color: _selectedCurrency.primaryColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            child: const Text('حفظ السقف'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      final val = double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0.0;
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.setBudgetLimit(
        categoryId: category.id,
        currency: _selectedCurrency,
        limit: val,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val > 0 ? 'تم تعيين سقف الميزانية بنجاح' : 'تم إلغاء سقف الميزانية'),
            backgroundColor: AppColors.primaryTeal,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    bool isExpense = true;
    int selectedIconCode = _availableIcons.first.codePoint;
    int selectedColorValue = _availableColors.first;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('إضافة تصنيف مخصص جديد', style: TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type switch
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('مصروف')),
                          selected: isExpense,
                          selectedColor: AppColors.expense.withValues(alpha: 0.2),
                          onSelected: (val) => setDialogState(() => isExpense = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('دخل')),
                          selected: !isExpense,
                          selectedColor: AppColors.income.withValues(alpha: 0.2),
                          onSelected: (val) => setDialogState(() => isExpense = false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  CustomTextField(
                    controller: nameController,
                    label: 'اسم التصنيف',
                    hint: 'مثال: هدايا ومناسبات',
                    prefixIcon: Icons.category_rounded,
                  ),

                  const SizedBox(height: 14),

                  const Text('اختر الأيقونة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableIcons.map((icon) {
                      final isSelected = icon.codePoint == selectedIconCode;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIconCode = icon.codePoint),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(selectedColorValue).withValues(alpha: 0.2)
                                : Colors.grey.shade200.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Color(selectedColorValue) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: isSelected ? Color(selectedColorValue) : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  const Text('اختر اللون:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.map((colorVal) {
                      final isSelected = colorVal == selectedColorValue;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColorValue = colorVal),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Color(colorVal).withValues(alpha: 0.5), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (!mounted) return;
      if (nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء كتابة اسم التصنيف')),
        );
        return;
      }

      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final newCat = CategoryModel(
        id: const Uuid().v4(),
        name: nameController.text.trim(),
        iconCode: selectedIconCode,
        colorValue: selectedColorValue,
        isExpense: isExpense,
        isDefault: false,
      );

      await categoryProvider.addCategory(newCat);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة التصنيف بنجاح'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final financeProvider = Provider.of<FinanceProvider>(context);

    // Calculate total allocated budget vs total spent for this currency
    double totalAllocatedBudget = 0.0;
    double totalSpentOnBudgetCategories = 0.0;

    for (final cat in categoryProvider.expenseCategories) {
      final b = cat.getBudgetForCurrency(_selectedCurrency);
      if (b > 0) {
        totalAllocatedBudget += b;
        totalSpentOnBudgetCategories += financeProvider.getCategoryMonthlySpending(
          cat.id,
          _selectedCurrency,
          month: _selectedMonth,
        );
      }
    }

    final totalBudgetRatio = totalAllocatedBudget > 0 ? (totalSpentOnBudgetCategories / totalAllocatedBudget) : 0.0;

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('الميزانية والتصنيفات'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'تصدير التقرير الشهري PDF',
                  onPressed: _exportMonthlyPdf,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'إضافة تصنيف جديد',
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Currency Selector Bar
          CurrencySelectorWidget(
            selectedCurrency: _selectedCurrency,
            onCurrencyChanged: (cur) => setState(() => _selectedCurrency = cur),
          ),

          const SizedBox(height: 12),

          // Month Navigation Bar & PDF Export Shortcut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  tooltip: 'الشهر التالي',
                  onPressed: () => _changeMonth(1),
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primaryTeal),
                    const SizedBox(width: 6),
                    Text(
                      DateFormatter.formatMonthYear(_selectedMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  tooltip: 'الشهر السابق',
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryTeal),
                  tooltip: 'تصدير التقرير الشهري PDF',
                  onPressed: _exportMonthlyPdf,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Total Monthly Budget Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF1F5F9)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي الميزانية المحددة للشهر',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      CurrencyFormatter.formatWithCurrency(totalAllocatedBudget, _selectedCurrency),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalBudgetRatio.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalBudgetRatio >= 1.0 ? AppColors.expense : AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي المنفق: ${CurrencyFormatter.formatWithCurrency(totalSpentOnBudgetCategories, _selectedCurrency)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      '${(totalBudgetRatio * 100).toStringAsFixed(0)}% مستهلك',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: totalBudgetRatio >= 1.0 ? AppColors.expense : AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Categories Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تصنيفات المصاريف (${categoryProvider.expenseCategories.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'اضغط لتحديد السقف',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Expense Categories List with Budgets
          ...categoryProvider.expenseCategories.map((cat) {
            final spent = financeProvider.getCategoryMonthlySpending(
              cat.id,
              _selectedCurrency,
              month: _selectedMonth,
            );
            return Dismissible(
              key: Key(cat.id),
              direction: cat.isDefault ? DismissDirection.none : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                color: AppColors.expense,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'حذف التصنيف',
                  content: 'هل أنت متأكد من حذف تصنيف "${cat.name}"؟',
                  confirmLabel: 'حذف',
                  confirmColor: AppColors.expense,
                );
                if (confirmed) {
                  await categoryProvider.deleteCategory(cat.id);
                }
                return false;
              },
              child: BudgetProgressCard(
                category: cat,
                currency: _selectedCurrency,
                spentAmount: spent,
                onSetBudget: () => _showSetBudgetDialog(cat),
                onTap: () => _navigateToCategoryDetails(cat),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Income Categories Section Header
          Text(
            'تصنيفات الدخل (${categoryProvider.incomeCategories.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          const SizedBox(height: 8),

          // Income Categories List
          ...categoryProvider.incomeCategories.map((cat) {
            final incomeTotal = financeProvider.getCategoryMonthlyTotal(
              cat.id,
              _selectedCurrency,
              month: _selectedMonth,
            );

            return Card(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _navigateToCategoryDetails(cat),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cat.iconData, color: cat.color, size: 20),
                  ),
                  title: Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    incomeTotal > 0
                        ? 'المحصل: ${CurrencyFormatter.formatWithCurrency(incomeTotal, _selectedCurrency)}'
                        : 'اضغط لعرض تفاصيل العمليات',
                    style: TextStyle(
                      fontSize: 11,
                      color: incomeTotal > 0 ? AppColors.income : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      fontWeight: incomeTotal > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!cat.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                          onPressed: () async {
                            final confirmed = await ConfirmDialog.show(
                              context,
                              title: 'حذف التصنيف',
                              content: 'هل تريد حذف تصنيف "${cat.name}"؟',
                              confirmLabel: 'حذف',
                            );
                            if (confirmed) {
                              await categoryProvider.deleteCategory(cat.id);
                            }
                          },
                        ),
                      const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 32),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        tooltip: 'إضافة تصنيف جديد',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
