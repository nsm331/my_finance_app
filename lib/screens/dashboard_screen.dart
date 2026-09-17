import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/currency_balance_card.dart';
import '../widgets/debt_summary_card.dart';
import '../widgets/transaction_list_tile.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/confirm_dialog.dart';
import '../core/constants/app_colors.dart';
import 'add_edit_transaction_screen.dart';
import 'add_edit_debt_screen.dart';
import 'categories_budget_screen.dart';
import 'currency_exchange_screen.dart';
import 'recurring_transactions_screen.dart';
import '../widgets/transfer_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTransactions;
  final VoidCallback? onNavigateToDebts;
  final VoidCallback? onNavigateToWallets;

  const DashboardScreen({
    super.key,
    this.onNavigateToTransactions,
    this.onNavigateToDebts,
    this.onNavigateToWallets,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppCurrency _selectedCurrency = AppCurrency.yer;
  final ScrollController _currencyScrollController = ScrollController();

  @override
  void dispose() {
    _currencyScrollController.dispose();
    super.dispose();
  }

  void _changeCurrency(AppCurrency cur) {
    setState(() {
      _selectedCurrency = cur;
    });

    if (!_currencyScrollController.hasClients) return;

    final index = AppCurrency.values.indexOf(cur);
    final screenWidth = MediaQuery.of(context).size.width;
    const cardWidth = 322.0; // 310 width + 12 horizontal margin
    final offset = (index * cardWidth) - (screenWidth / 2) + (cardWidth / 2) + 10; // +10 for listview padding

    _currencyScrollController.animateTo(
      offset.clamp(0.0, _currencyScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final debtProvider = Provider.of<DebtProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);

    final recentTransactions = financeProvider.selectedDashboardWalletId != null
        ? financeProvider.transactions
            .where((t) => t.walletId == financeProvider.selectedDashboardWalletId)
            .take(5)
            .toList()
        : financeProvider.getRecentTransactions(limit: 5);

    // Filter categories with high budget usage for selected currency
    final warningBudgetCategories = categoryProvider.expenseCategories.where((cat) {
      final budget = cat.getBudgetForCurrency(_selectedCurrency);
      if (budget <= 0) return false;
      final spent = financeProvider.getCategoryMonthlySpending(cat.id, _selectedCurrency);
      return (spent / budget) >= 0.8; // Over 80% or exceeded
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await financeProvider.loadAllData();
        await debtProvider.loadAll();
        await categoryProvider.loadCategories();
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Wallet Filter Dropdown Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'عرض رصيد الحسابات:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: financeProvider.selectedDashboardWalletId,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.primaryTeal,
                      ),
                      elevation: 3,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      onChanged: (int? newWalletId) {
                        financeProvider.setDashboardWalletFilter(newWalletId);
                      },
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.all_inclusive_rounded, size: 16, color: AppColors.primaryTeal),
                              const SizedBox(width: 6),
                              const Text('الإجمالي (كافة المحافظ)'),
                            ],
                          ),
                        ),
                        ...financeProvider.wallets.map((wallet) {
                          return DropdownMenuItem<int?>(
                            value: wallet.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(wallet.iconData, size: 16, color: wallet.color),
                                const SizedBox(width: 6),
                                Text(wallet.name),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Currency Cards Carousel / Horizontal Scroll
            SizedBox(
              height: 210,
              child: ListView.builder(
                controller: _currencyScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: AppCurrency.values.length,
                itemBuilder: (context, index) {
                  final cur = AppCurrency.values[index];
                  final balance = financeProvider.getTotalBalance(cur);
                  final income = financeProvider.getTotalIncome(cur);
                  final expense = financeProvider.getTotalExpense(cur);
                  final isSelected = cur == _selectedCurrency;

                  return CurrencyBalanceCard(
                    currency: cur,
                    balance: balance,
                    income: income,
                    expense: expense,
                    isSelected: isSelected,
                    onTap: () => _changeCurrency(cur),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Quick Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildQuickActionBtn(
                        icon: Icons.remove_rounded,
                        label: 'إضافة مصروف',
                        color: AppColors.expense,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditTransactionScreen(
                                initialCurrency: _selectedCurrency,
                                initialIsExpense: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionBtn(
                        icon: Icons.add_rounded,
                        label: 'إضافة دخل',
                        color: AppColors.income,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditTransactionScreen(
                                initialCurrency: _selectedCurrency,
                                initialIsExpense: false,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildQuickActionBtn(
                        icon: Icons.handshake_rounded,
                        label: 'تسجيل دين',
                        color: AppColors.sarColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditDebtScreen(
                                initialCurrency: _selectedCurrency,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickActionBtn(
                        icon: Icons.currency_exchange_rounded,
                        label: 'صرافة العملات',
                        color: const Color(0xFF0284C7),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CurrencyExchangeScreen(
                                initialFromCurrency: _selectedCurrency,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionBtn(
                        icon: Icons.sync_alt_rounded,
                        label: 'تحويل المحافظ',
                        color: AppColors.primaryTeal,
                        onTap: () => TransferSheet.show(context),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickActionBtn(
                        icon: Icons.event_repeat_rounded,
                        label: 'العمليات المجدولة',
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecurringTransactionsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Debt Summary for selected currency
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DebtSummaryCard(
                currency: _selectedCurrency,
                lentRemaining: debtProvider.getRemainingLent(_selectedCurrency),
                borrowedRemaining: debtProvider.getRemainingBorrowed(_selectedCurrency),
                onDetailsTap: widget.onNavigateToDebts,
              ),
            ),

            // Budget Warnings Section (if any exceeded or near limit)
            if (warningBudgetCategories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'تنبيهات الميزانية الشهرية (${_selectedCurrency.nameAr})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...warningBudgetCategories.map((cat) {
                final spent = financeProvider.getCategoryMonthlySpending(cat.id, _selectedCurrency);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BudgetProgressCard(
                    category: cat,
                    currency: _selectedCurrency,
                    spentAmount: spent,
                    onSetBudget: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoriesBudgetScreen(),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),

            // Recent Transactions Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'أحدث العمليات',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.onNavigateToTransactions != null)
                    TextButton(
                      onPressed: widget.onNavigateToTransactions,
                      child: const Text('عرض الكل'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Recent Transactions List
            if (recentTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد عمليات مسجلة حتى الآن',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  itemBuilder: (context, index) {
                    final item = recentTransactions[index];
                    return TransactionListTile(
                      transaction: item,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditTransactionScreen(
                              transactionToEdit: item,
                            ),
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirmed = await ConfirmDialog.show(
                          context,
                          title: 'حذف العملية',
                          content: 'هل أنت متأكد من رغبتك في حذف عملية "${item.title}"؟',
                          confirmLabel: 'حذف',
                          confirmColor: AppColors.expense,
                        );
                        if (confirmed) {
                          await financeProvider.deleteTransaction(item.id);
                        }
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      );
  }
}
