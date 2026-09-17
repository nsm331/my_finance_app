import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';
import '../models/app_currency.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../providers/debt_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/custom_text_field.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import 'add_edit_debt_screen.dart';

import '../services/pdf_statement_service.dart';
import 'person_statement_screen.dart';

class DebtDetailsScreen extends StatefulWidget {
  final String debtId;

  const DebtDetailsScreen({super.key, required this.debtId});

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  Future<void> _exportPdf(DebtModel debt) async {
    await PdfStatementService.exportDebtStatement(context, debt);
  }

  Future<void> _showEditPaymentDialog(DebtModel debt, DebtPaymentModel payment) async {
    final amountController = TextEditingController(
      text: payment.amount % 1 == 0 ? payment.amount.toInt().toString() : payment.amount.toString(),
    );
    final noteController = TextEditingController(text: payment.note ?? '');
    DateTime selectedDate = payment.date;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.primaryTeal),
                  SizedBox(width: 8),
                  Text('تعديل الدفعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: amountController,
                      label: 'مبلغ الدفعة',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.attach_money_rounded,
                      suffix: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          debt.currency.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: debt.currency.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('تاريخ الدفعة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            );
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primaryTeal),
                            const SizedBox(width: 10),
                            Text(
                              DateFormatter.formatFullDate(selectedDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: noteController,
                      label: 'ملاحظة',
                      hint: 'مثال: دفعة نقدية / تحويل بنكي',
                      prefixIcon: Icons.edit_note_rounded,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final newAmount = double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
      if (newAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')),
        );
        return;
      }

      final updatedPayment = DebtPaymentModel(
        id: payment.id,
        debtId: payment.debtId,
        amount: newAmount,
        date: selectedDate,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        impactsBalance: payment.impactsBalance,
      );

      await Provider.of<DebtProvider>(context, listen: false).updatePayment(
        debtId: debt.id,
        updatedPayment: updatedPayment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعديل الدفعة وتحديث الرصيد بنجاح'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDeletePayment(DebtModel debt, DebtPaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد حذف الدفعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الدفعة بمبلغ ${CurrencyFormatter.formatWithCurrency(payment.amount, debt.currency)}؟ سيتم إعادة احتساب المبلغ المتبقي على الدين.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<DebtProvider>(context, listen: false).deletePayment(
        debtId: debt.id,
        paymentId: payment.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الدفعة وتحديث الرصيد المتبقي بنجاح'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _showPaymentDialog(DebtModel debt, {double? defaultAmount}) async {
    final amountController = TextEditingController(
      text: defaultAmount != null ? (defaultAmount % 1 == 0 ? defaultAmount.toInt().toString() : defaultAmount.toString()) : '',
    );
    final noteController = TextEditingController();
    bool reflectOnBalance = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isForMe = debt.type == DebtType.forMe;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.payment_rounded, color: AppColors.primaryTeal),
                  const SizedBox(width: 8),
                  const Text('تسديد دفعة من الدين', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المتبقي على هذا الدين: ${CurrencyFormatter.formatWithCurrency(debt.remainingAmount, debt.currency)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: amountController,
                      label: 'مبلغ الدفعة',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.money_rounded,
                      suffix: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          debt.currency.symbol,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: debt.currency.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: noteController,
                      label: 'ملاحظة (اختياري)',
                      hint: 'مثال: دفعة نقدية / تحويل بنكي',
                      prefixIcon: Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: reflectOnBalance,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        isForMe
                            ? 'إضافة الدفعة كـ "دخل" في سجل العمليات؟'
                            : 'خصم الدفعة كـ "مصروف" في سجل العمليات؟',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isForMe
                            ? 'سيتم زيادة رصيدك المالي بمقدار هذه الدفعة'
                            : 'سيتم خصم هذا المبلغ من رصيدك المالي',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          reflectOnBalance = val ?? true;
                        });
                      },
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                  ),
                  child: const Text('تسجيل الدفعة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      if (!mounted) return;
      final amount = double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')),
        );
        return;
      }

      final debtProvider = Provider.of<DebtProvider>(context, listen: false);
      final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

      await debtProvider.recordPayment(
        debtId: debt.id,
        amount: amount,
        date: DateTime.now(),
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        impactsBalance: reflectOnBalance,
      );

      // If user chose to reflect in transactions balance
      if (reflectOnBalance) {
        final isForMe = debt.type == DebtType.forMe;
        // Find or use default category
        final defaultCat = isForMe
            ? (categoryProvider.incomeCategories.isNotEmpty ? categoryProvider.incomeCategories.first : CategoryModel.defaultCategories.first)
            : (categoryProvider.expenseCategories.isNotEmpty ? categoryProvider.expenseCategories.first : CategoryModel.defaultCategories.first);

        final transaction = TransactionModel(
          id: const Uuid().v4(),
          title: isForMe ? 'استلام سداد دين: ${debt.personName}' : 'سداد دفعة دين: ${debt.personName}',
          amount: amount,
          currency: debt.currency,
          type: isForMe ? TransactionType.income : TransactionType.expense,
          categoryId: defaultCat.id,
          categoryName: 'تسديد ديون',
          categoryIconCode: Icons.handshake_rounded.codePoint,
          categoryColorValue: isForMe ? AppColors.debtForMe.toARGB32() : AppColors.debtOnMe.toARGB32(),
          date: DateTime.now(),
          notes: noteController.text.trim().isEmpty ? 'سداد مرتبط بدين ${debt.personName}' : noteController.text.trim(),
        );

        await financeProvider.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل دفعة السداد بنجاح'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtProvider = Provider.of<DebtProvider>(context);
    final debt = debtProvider.findById(widget.debtId);

    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الدين')),
        body: const Center(child: Text('هذا الدين غير موجود أو تم حذفه')),
      );
    }

    final isForMe = debt.type == DebtType.forMe;
    final themeColor = isForMe ? AppColors.debtForMe : AppColors.debtOnMe;
    final isSettled = debt.isSettled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الدين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير كشف حساب PDF',
            onPressed: () => _exportPdf(debt),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditDebtScreen(debtToEdit: debt),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            tooltip: 'حذف',
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'حذف الدين',
                content: 'هل أنت متأكد من رغبتك في حذف دين "${debt.personName}" وسجل دفعاته بالكامل؟',
                confirmLabel: 'حذف',
                confirmColor: AppColors.expense,
              );
              if (confirmed) {
                await debtProvider.deleteDebt(debt.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isForMe
                    ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                    : [const Color(0xFF9F1239), const Color(0xFFF43F5E)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        debt.type.nameAr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSettled ? Colors.green.shade900 : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isSettled ? '✓ مسدد بالكامل' : 'قائم غير مسدد',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  debt.personName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (debt.phone != null && debt.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    debt.phone!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Remaining Amount
                Text(
                  'المبلغ المتبقي',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatWithCurrency(debt.remainingAmount, debt.currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Shortcut to Person Ledger Statement
          if (debt.personId != null) ...[
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonStatementScreen(personId: debt.personId!),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_box_rounded, color: AppColors.primaryTeal, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'عرض كشف الحساب الشامل لـ ${debt.personName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryTeal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Amounts Stats (Total / Paid)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي الدين الأصلي',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatWithCurrency(debt.totalAmount, debt.currency),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المسدد حتى الآن',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatWithCurrency(debt.paidAmount, debt.currency),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
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
                      'نسبة السداد',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(debt.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSettled ? AppColors.income : themeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: debt.progress,
                    minHeight: 10,
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSettled ? AppColors.income : themeColor,
                    ),
                  ),
                ),
                if (debt.dueDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'موعد الاستحقاق: ${DateFormatter.formatFullDate(debt.dueDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: ${debt.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Payment Action Buttons
          if (!isSettled) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(debt),
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('تسديد دفعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPaymentDialog(debt, defaultAmount: debt.remainingAmount),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('تسديد كامل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // PDF Statement Share Button (Available for active & settled debts)
          OutlinedButton.icon(
            onPressed: () => _exportPdf(debt),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: Text(
              isSettled
                  ? 'مشاركة سند براءة الذمة وكشف الحساب (PDF / واتساب)'
                  : 'تصدير ومشاركة كشف الحساب (PDF / واتساب)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isSettled ? AppColors.income : AppColors.primaryTeal,
              side: BorderSide(
                color: isSettled ? AppColors.income : AppColors.primaryTeal,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          // Payments Timeline History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل الدفعات (${debt.payments.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (debt.payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Text(
                'لم يتم تسجيل أي دفعات سداد لهذا الدين بعد',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: debt.payments.length,
              itemBuilder: (context, index) {
                final payment = debt.payments[index];
                return Dismissible(
                  key: ValueKey('payment_dismiss_${payment.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'حذف الدفعة',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) => _confirmDeletePayment(debt, payment),
                  child: Card(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.income, size: 18),
                      ),
                      title: Text(
                        CurrencyFormatter.formatWithCurrency(payment.amount, debt.currency),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${DateFormatter.formatFullDate(payment.date)}${payment.note != null ? ' • ${payment.note}' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'تعديل الدفعة',
                            onPressed: () => _showEditPaymentDialog(debt, payment),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                            tooltip: 'حذف الدفعة',
                            onPressed: () => _confirmDeletePayment(debt, payment),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
