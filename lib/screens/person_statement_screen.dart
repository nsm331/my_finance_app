import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person_model.dart';
import '../models/debt_model.dart';
import '../models/app_currency.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_list_tile.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../services/pdf_statement_service.dart';
import '../widgets/report_date_range_dialog.dart';
import 'add_edit_debt_screen.dart';
import 'debt_details_screen.dart';
import '../core/utils/contact_picker_helper.dart';

class PersonStatementScreen extends StatefulWidget {
  final String personId;

  const PersonStatementScreen({super.key, required this.personId});

  @override
  State<PersonStatementScreen> createState() => _PersonStatementScreenState();
}

class _PersonStatementScreenState extends State<PersonStatementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditPersonDialog(PersonModel person) {
    final nameController = TextEditingController(text: person.name);
    final phoneController = TextEditingController(text: person.phone ?? '');
    final notesController = TextEditingController(text: person.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.primaryTeal),
              SizedBox(width: 8),
              Text('تعديل بيانات الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الشخص / الجهة *',
                    prefixIcon: const Icon(Icons.person_outline),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contact_phone_outlined, color: AppColors.primaryTeal),
                      tooltip: 'استيراد من جهات الاتصال',
                      onPressed: () async {
                        final picked = await ContactPickerHelper.pickContact(ctx);
                        if (picked != null) {
                          nameController.text = picked.name;
                          if (picked.phone != null) {
                            phoneController.text = picked.phone!;
                          }
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contact_phone_outlined, color: AppColors.primaryTeal),
                      tooltip: 'استيراد من جهات الاتصال',
                      onPressed: () async {
                        final picked = await ContactPickerHelper.pickContact(ctx);
                        if (picked != null) {
                          if (nameController.text.trim().isEmpty) {
                            nameController.text = picked.name;
                          }
                          if (picked.phone != null) {
                            phoneController.text = picked.phone!;
                          }
                        }
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات إضافية',
                    prefixIcon: const Icon(Icons.note_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;
                final updated = person.copyWith(
                  name: newName,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                await Provider.of<DebtProvider>(context, listen: false).updatePerson(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
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
  }

  Future<void> _exportPdf(PersonModel person, List<DebtModel> debts, DebtProvider provider) async {
    final result = await ReportDateRangeDialog.show(
      context,
      title: 'كشف حساب: ${person.name}',
      subtitle: 'حدد الفترة المطلوبة أو اختر طباعة كشف شامل لكافة الحركات',
    );

    if (result != null && mounted) {
      await PdfStatementService.exportPersonStatement(
        context,
        person,
        debts,
        provider,
        startDate: result.isAll ? null : result.startDate,
        endDate: result.isAll ? null : result.endDate,
      );
    }
  }

  Future<void> _confirmDeletePerson(PersonModel person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذا الشخص؟ سيتم حذف جميع الديون المرتبطة به.',
          style: TextStyle(fontSize: 14),
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
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<DebtProvider>(context, listen: false).deletePerson(person.id, cascadeDebts: true);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف حساب "${person.name}" وجميع ديونه بنجاح'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtProvider = Provider.of<DebtProvider>(context);

    final person = debtProvider.findPersonById(widget.personId);
    if (person == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('كشف حساب')),
        body: const Center(child: Text('لم يتم العثور على هذا الشخص أو تم حذفه.')),
      );
    }

    final personDebts = debtProvider.getDebtsForPerson(person.id);
    final allPayments = debtProvider.getAllPaymentsForPerson(person.id);

    // Filter currencies with activity
    final activeCurrencies = AppCurrency.values.where((c) {
      return personDebts.any((d) => d.currency == c);
    }).toList();
    if (activeCurrencies.isEmpty) {
      activeCurrencies.add(AppCurrency.yer);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير كشف حساب PDF',
            onPressed: () => _exportPdf(person, personDebts, debtProvider),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل البيانات',
            onPressed: () => _showEditPersonDialog(person),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'حذف الشخص وديونه',
            onPressed: () => _confirmDeletePerson(person),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Person Contact Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryTeal, AppColors.primaryTealLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                person.name.isNotEmpty ? person.name.substring(0, 1) : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (person.phone != null && person.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 14, color: AppColors.primaryTeal),
                                      const SizedBox(width: 6),
                                      Text(
                                        person.phone!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (person.notes != null && person.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    person.notes!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Net Balances Summary by Currency
                    const Text(
                      'ملخص الأرصدة الصافية:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: activeCurrencies.length,
                        itemBuilder: (context, idx) {
                          final cur = activeCurrencies[idx];
                          final lentRem = debtProvider.getRemainingLentForPerson(person.id, cur);
                          final borrowedRem = debtProvider.getRemainingBorrowedForPerson(person.id, cur);
                          final net = lentRem - borrowedRem;
                          final isPositive = net > 0.001; // أطلب منه
                          final isNegative = net < -0.001; // يطلب مني
                          final isZero = !isPositive && !isNegative;

                          return Container(
                            width: 250,
                            margin: const EdgeInsets.only(left: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isZero
                                  ? (isDark ? AppColors.darkSurface : Colors.grey.shade100)
                                  : isPositive
                                      ? AppColors.income.withValues(alpha: isDark ? 0.15 : 0.08)
                                      : AppColors.expense.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isZero
                                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                    : isPositive
                                        ? AppColors.income.withValues(alpha: 0.3)
                                        : AppColors.expense.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      cur.nameAr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cur.primaryColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cur.symbol,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cur.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('له عندك (التزام):', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                        Text(CurrencyFormatter.formatAmount(borrowedRem), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.expense)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('لك عنده (مستحق):', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                        Text(CurrencyFormatter.formatAmount(lentRem), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.income)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isZero
                                            ? Colors.grey
                                            : isPositive
                                                ? AppColors.income
                                                : AppColors.expense)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isZero
                                            ? 'الرصيد الصافي:'
                                            : isPositive
                                                ? 'صافي مستحق لك:'
                                                : 'صافي مستحق له:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isZero
                                              ? (isDark ? Colors.white70 : Colors.black87)
                                              : (isPositive ? AppColors.income : AppColors.expense),
                                        ),
                                      ),
                                      Text(
                                        isZero ? '0.00 (خالص)' : CurrencyFormatter.formatWithCurrency(net.abs(), cur),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isZero
                                              ? (isDark ? Colors.white70 : Colors.black87)
                                              : (isPositive ? AppColors.income : AppColors.expense),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryTeal,
                  labelColor: AppColors.primaryTeal,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: 'سجل الديون (${personDebts.length})'),
                    Tab(text: 'سجل الدفعات (${allPayments.length})'),
                  ],
                ),
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Debts List
            personDebts.isEmpty
                ? const Center(child: Text('لا توجد ديون مسجلة مع هذا الشخص'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: personDebts.length,
                    itemBuilder: (context, index) {
                      final debt = personDebts[index];
                      return DebtListTile(
                        debt: debt,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DebtDetailsScreen(debtId: debt.id),
                            ),
                          );
                        },
                        onPaymentTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DebtDetailsScreen(debtId: debt.id),
                            ),
                          );
                        },
                      );
                    },
                  ),

            // Tab 2: Payment History
            allPayments.isEmpty
                ? const Center(child: Text('لا توجد دفعات مسددة حتى الآن'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: allPayments.length,
                    itemBuilder: (context, index) {
                      final payment = allPayments[index];
                      // Find parent debt currency
                      final parentDebt = personDebts.firstWhere(
                        (d) => d.id == payment.debtId,
                        orElse: () => personDebts.first,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.check_rounded, color: AppColors.income, size: 20),
                          ),
                          title: Text(
                            CurrencyFormatter.formatWithCurrency(payment.amount, parentDebt.currency),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${DateFormatter.formatDate(payment.date)} • ${(payment.note != null && payment.note!.isNotEmpty) ? payment.note! : "دفعة سداد"}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: parentDebt.type == DebtType.forMe
                                  ? AppColors.income.withValues(alpha: 0.15)
                                  : AppColors.expense.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              parentDebt.type == DebtType.forMe ? 'سداد لدينك' : 'سداد لالتزامك',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: parentDebt.type == DebtType.forMe
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditDebtScreen(
                initialPersonId: person.id,
                initialPersonName: person.name,
                initialPhone: person.phone,
              ),
            ),
          );
        },
        tooltip: 'إضافة معاملة دين',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  _SliverTabBarDelegate(this.tabBar, {required this.color});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
