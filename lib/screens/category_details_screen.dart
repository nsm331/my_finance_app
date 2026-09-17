import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/currency_selector_widget.dart';
import '../widgets/custom_text_field.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../services/pdf_report_service.dart';
import 'add_edit_transaction_screen.dart';

class CategoryDetailsScreen extends StatefulWidget {
  final CategoryModel category;
  final DateTime selectedMonth;
  final AppCurrency? initialCurrency;

  const CategoryDetailsScreen({
    super.key,
    required this.category,
    required this.selectedMonth,
    this.initialCurrency,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  late AppCurrency _selectedCurrency;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency ?? AppCurrency.yer;
    _currentMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
  }

  Future<void> _exportPdf(List<TransactionModel> transactions, CategoryModel category) async {
    final filename = 'تقرير_تصنيف_${category.name}_${_currentMonth.year}_${_currentMonth.month}.pdf';
    await PdfReportService.showReportModal(
      context,
      title: 'تقرير تصنيف: ${category.name}',
      filename: filename,
      onGenerateBytes: () => PdfReportService.generateCategoryReportBytes(
        category: category,
        month: _currentMonth,
        categoryTransactions: transactions,
        currency: _selectedCurrency,
      ),
    );
  }

  Future<void> _showSetBudgetDialog(CategoryModel category) async {
    final currentBudget = category.getBudgetForCurrency(_selectedCurrency);
    final controller = TextEditingController(
      text: currentBudget > 0
          ? (currentBudget % 1 == 0 ? currentBudget.toInt().toString() : currentBudget.toString())
          : '',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    // Refresh category instance from provider to pick up any updated budgets
    final currentCategory = categoryProvider.categories.firstWhere(
      (c) => c.id == widget.category.id,
      orElse: () => widget.category,
    );

    // Fetch transactions for this category and current month
    final transactions = financeProvider.getTransactionsForCategoryAndMonth(
      categoryId: currentCategory.id,
      month: _currentMonth,
      currency: _selectedCurrency,
    );

    final totalAmount = transactions.fold(0.0, (s, t) => s + t.amount);
    final budgetLimit = currentCategory.getBudgetForCurrency(_selectedCurrency);
    final hasBudget = budgetLimit > 0 && currentCategory.isExpense;
    final budgetRatio = hasBudget ? (totalAmount / budgetLimit) : 0.0;

    Color progressColor;
    if (budgetRatio >= 1.0) {
      progressColor = AppColors.expense;
    } else if (budgetRatio >= 0.8) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = AppColors.income;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: currentCategory.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(currentCategory.iconData, color: currentCategory.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                currentCategory.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير تقرير التصنيف PDF',
            onPressed: () => _exportPdf(transactions, currentCategory),
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

          // Month Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      DateFormatter.formatMonthYear(_currentMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  tooltip: 'الشهر السابق',
                  onPressed: () => _changeMonth(-1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasBudget && budgetRatio >= 1.0
                    ? AppColors.expense.withValues(alpha: 0.5)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: hasBudget && budgetRatio >= 1.0 ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currentCategory.isExpense ? 'إجمالي المنفق في هذا الشهر' : 'إجمالي الدخل المحصل',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (currentCategory.isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentCategory.isExpense ? 'مصروف' : 'دخل',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: currentCategory.isExpense ? AppColors.expense : AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.formatWithCurrency(totalAmount, _selectedCurrency),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: currentCategory.isExpense ? AppColors.expense : AppColors.income,
                  ),
                ),

                if (currentCategory.isExpense) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  if (hasBudget) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سقف الميزانية: ${CurrencyFormatter.formatWithCurrency(budgetLimit, _selectedCurrency)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(budgetRatio * 100).toStringAsFixed(0)}% مستهلك',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: budgetRatio.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          budgetRatio > 1.0
                              ? 'تجاوزت السقف بـ ${CurrencyFormatter.formatWithCurrency(totalAmount - budgetLimit, _selectedCurrency)}'
                              : 'المتبقي من السقف: ${CurrencyFormatter.formatWithCurrency(budgetLimit - totalAmount, _selectedCurrency)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progressColor,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showSetBudgetDialog(currentCategory),
                          child: const Text(
                            'تعديل السقف',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'لم يتم تحديد سقف شهري لهذا التصنيف',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () => _showSetBudgetDialog(currentCategory),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('تعيين سقف +', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Transactions List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'العمليات المسجلة (${transactions.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (transactions.isNotEmpty)
                Text(
                  'انقر لتعديل العملية',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Transactions ListView
          if (transactions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد عمليات مسجلة في شهر ${DateFormatter.formatMonthYear(_currentMonth)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isExpense = tx.type == TransactionType.expense;

                return Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditTransactionScreen(transactionToEdit: tx),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isExpense ? AppColors.expense : AppColors.income,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.title.isNotEmpty ? tx.title : currentCategory.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      DateFormatter.formatDate(tx.date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    if (tx.notes != null && tx.notes!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          tx.notes!.trim(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatWithCurrency(tx.amount, tx.currency),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isExpense ? AppColors.expense : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
