import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt_model.dart';
import '../models/app_currency.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_list_tile.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import 'add_edit_debt_screen.dart';
import 'debt_details_screen.dart';
import 'person_statement_screen.dart';
import '../services/pdf_statement_service.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  AppCurrency? _selectedCurrencyFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddNewPersonDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryTeal),
              SizedBox(width: 8),
              Text('إضافة حساب شخص جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: const Icon(Icons.notes_outlined),
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final newP = await Provider.of<DebtProvider>(context, listen: false).addPerson(
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonStatementScreen(personId: newP.id),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('إضافة وفتح الحساب'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context, DebtProvider debtProvider) async {
    if (debtProvider.debts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد ديون مسجلة لتصديرها')),
      );
      return;
    }
    await PdfStatementService.showComprehensiveDebtsExportBottomSheet(
      context: context,
      debts: debtProvider.debts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtProvider = Provider.of<DebtProvider>(context);

    return Scaffold(
      body: Column(
        children: [
        // TabBar
        Container(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryTeal,
            labelColor: AppColors.primaryTeal,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            isScrollable: true,
            tabs: [
              Tab(text: 'سجل الأشخاص (${debtProvider.persons.length})'),
              const Tab(text: 'ديون لي (مستحقات)'),
              const Tab(text: 'ديون علي (التزامات)'),
              const Tab(text: 'الأرشيف والمسددة'),
            ],
          ),
        ),
        // Filter & Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الشخص أو الهاتف أو الملاحظات...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primaryTeal),
                    tooltip: 'تصدير كشف الديون PDF',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () => _exportPdf(context, debtProvider),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                    tooltip: 'إضافة شخص جديد',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: _showAddNewPersonDialog,
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    tooltip: 'تسجيل دين جديد',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.income,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      final activeIndex = _tabController.index;
                      final initialType = activeIndex == 2 ? DebtType.onMe : DebtType.forMe;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditDebtScreen(
                            initialCurrency: _selectedCurrencyFilter,
                            initialDebtType: initialType,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

                const SizedBox(height: 10),

                // Currency Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: const Text('جميع العملات'),
                          selected: _selectedCurrencyFilter == null,
                          onSelected: (_) => setState(() => _selectedCurrencyFilter = null),
                          selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primaryTeal,
                        ),
                      ),
                      ...AppCurrency.values.map((cur) {
                        final isSelected = _selectedCurrencyFilter == cur;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            avatar: Icon(cur.icon, size: 14, color: isSelected ? Colors.white : cur.primaryColor),
                            label: Text(cur.nameAr),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCurrencyFilter = isSelected ? null : cur),
                            selectedColor: cur.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Persons Ledger
                _buildPersonsLedgerList(debtProvider),

                // Tab 1: ديون لي (Unsettled For Me)
                _buildDebtsList(
                  debtProvider.filterDebts(
                    currency: _selectedCurrencyFilter,
                    type: DebtType.forMe,
                    isSettled: false,
                    searchQuery: _searchController.text,
                  ),
                  emptyMessage: 'لا توجد ديون مستحقة لك حالياً',
                ),

                // Tab 2: ديون علي (Unsettled On Me)
                _buildDebtsList(
                  debtProvider.filterDebts(
                    currency: _selectedCurrencyFilter,
                    type: DebtType.onMe,
                    isSettled: false,
                    searchQuery: _searchController.text,
                  ),
                  emptyMessage: 'لا توجد ديون أو التزامات مسجلة عليك',
                ),

                // Tab 3: All Settled Debts
                _buildDebtsList(
                  debtProvider.filterDebts(
                    currency: _selectedCurrencyFilter,
                    isSettled: true,
                    searchQuery: _searchController.text,
                  ),
                  emptyMessage: 'لا توجد ديون مسددة في الأرشيف',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final activeIndex = _tabController.index;
          final initialType = activeIndex == 2 ? DebtType.onMe : DebtType.forMe;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditDebtScreen(
                initialCurrency: _selectedCurrencyFilter,
                initialDebtType: initialType,
              ),
            ),
          );
        },
        tooltip: 'تسجيل دين جديد',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildPersonsLedgerList(DebtProvider debtProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawPersons = debtProvider.filterPersons(_searchController.text);
    final seenIds = <String>{};
    final persons = rawPersons.where((p) => seenIds.add(p.id)).toList();

    if (persons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 54,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'لا يوجد أشخاص مسجلين في دفتر الأستاذ',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showAddNewPersonDialog,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('إضافة شخص جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: persons.length,
      itemBuilder: (context, index) {
        final person = persons[index];
        final debts = debtProvider.getDebtsForPerson(person.id);
        final activeDebts = debts.where((d) => !d.isSettled).length;

        // Collect net balances per active currency
        final activeCurrencies = AppCurrency.values.where((c) {
          if (_selectedCurrencyFilter != null && _selectedCurrencyFilter != c) return false;
          return debts.any((d) => d.currency == c);
        }).toList();

        return Card(
          key: ValueKey('person_card_${person.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonStatementScreen(personId: person.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
                        child: Text(
                          person.name.isNotEmpty ? person.name.substring(0, 1) : '?',
                          style: const TextStyle(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (person.phone != null && person.phone!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                person.phone!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (activeDebts > 0 ? AppColors.primaryTeal : Colors.grey)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeDebts دين قائم',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: activeDebts > 0 ? AppColors.primaryTeal : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),

                  if (activeCurrencies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: activeCurrencies.map((cur) {
                        final net = debtProvider.getNetBalanceForPerson(person.id, cur);
                        final isPositive = net > 0.001;
                        final isNegative = net < -0.001;
                        final isZero = !isPositive && !isNegative;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isZero
                                    ? Colors.grey
                                    : isPositive
                                        ? AppColors.income
                                        : AppColors.expense)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isZero
                                      ? Colors.grey
                                      : isPositive
                                          ? AppColors.income
                                          : AppColors.expense)
                                  .withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isZero
                                ? '${cur.nameAr}: خالص ومسدد'
                                : isPositive
                                    ? '${cur.nameAr}: صافي لك ${CurrencyFormatter.formatAmount(net)}'
                                    : '${cur.nameAr}: صافي عليه/لك ${CurrencyFormatter.formatAmount(net.abs())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isZero
                                  ? (isDark ? Colors.white70 : Colors.black87)
                                  : (isPositive ? AppColors.income : AppColors.expense),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebtsList(List<DebtModel> rawList, {required String emptyMessage}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seen = <String>{};
    final list = rawList.where((d) => seen.add(d.id)).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 54,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final debt = list[index];
        return DebtListTile(
          key: ValueKey('debt_tile_${debt.id}'),
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
    );
  }
}
