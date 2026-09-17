import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../widgets/transaction_list_tile.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/report_date_range_dialog.dart';
import '../core/constants/app_colors.dart';
import 'add_edit_transaction_screen.dart';
import '../services/pdf_statement_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedFilterTab = 0; // 0: الكل, 1: مصاريف, 2: مداخيل, 3: تحويلات
  AppCurrency? _selectedCurrencyFilter; // null = all

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(BuildContext context, List<TransactionModel> filteredList) async {
    final result = await ReportDateRangeDialog.show(context);
    if (result == null || !context.mounted) return;

    List<TransactionModel> transactionsToExport;
    DateTime? exportStartDate;
    DateTime? exportEndDate;

    if (result.isAll) {
      transactionsToExport = filteredList;
    } else if (result.startDate != null && result.endDate != null) {
      exportStartDate = result.startDate;
      exportEndDate = result.endDate;
      transactionsToExport = filteredList.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        final sDate = DateTime(result.startDate!.year, result.startDate!.month, result.startDate!.day);
        final eDate = DateTime(result.endDate!.year, result.endDate!.month, result.endDate!.day);
        return tDate.isAtSameMomentAs(sDate) ||
               tDate.isAtSameMomentAs(eDate) ||
               (tDate.isAfter(sDate) && tDate.isBefore(eDate));
      }).toList();
    } else {
      transactionsToExport = filteredList;
    }

    if (transactionsToExport.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد عمليات لتصديرها في هذا النطاق')),
        );
      }
      return;
    }

    if (context.mounted) {
      await PdfStatementService.showTransactionExportBottomSheet(
        context: context,
        transactions: transactionsToExport,
        startDate: exportStartDate,
        endDate: exportEndDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);

    final filteredList = financeProvider.filterTransactions(
      currency: _selectedCurrencyFilter,
      type: _selectedFilterTab == 1
          ? TransactionType.expense
          : (_selectedFilterTab == 2 ? TransactionType.income : null),
      isWalletTransfer: _selectedFilterTab == 1 || _selectedFilterTab == 2
          ? false
          : (_selectedFilterTab == 3 ? true : null),
      searchQuery: _searchController.text,
    );

    return Scaffold(
      body: Column(
        children: [
        // Search & Filter Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
              // Search Bar + PDF Export Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن عملية، تصنيف، ملاحظة...',
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
                    tooltip: 'تصدير وطباعة PDF',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () => _exportPdf(context, filteredList),
                  ),
                ],
              ),

                const SizedBox(height: 12),

                // Type Filter Pills (الكل / مصاريف / مداخيل / تحويلات)
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeFilterChip(
                        label: 'الكل',
                        isSelected: _selectedFilterTab == 0,
                        onTap: () => setState(() => _selectedFilterTab = 0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTypeFilterChip(
                        label: 'مصاريف',
                        color: AppColors.expense,
                        isSelected: _selectedFilterTab == 1,
                        onTap: () => setState(() => _selectedFilterTab = 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTypeFilterChip(
                        label: 'مداخيل',
                        color: AppColors.income,
                        isSelected: _selectedFilterTab == 2,
                        onTap: () => setState(() => _selectedFilterTab = 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildTypeFilterChip(
                        label: 'تحويلات',
                        color: const Color(0xFF0284C7),
                        isSelected: _selectedFilterTab == 3,
                        onTap: () => setState(() => _selectedFilterTab = 3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Currency Filter Pills (الكل, YER, SAR, USD)
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

          // Count & Total header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'النتائج (${filteredList.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 54,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد عمليات مطابقة لخيارات البحث',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return TransactionListTile(
                        transaction: item,
                        onTap: () {
                          if (item.isTransferBool) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('عمليات التحويل بين المحافظ لا يمكن تعديلها، يمكنك حذفها وإعادة التحويل إن لزم الأمر.'),
                              ),
                            );
                            return;
                          }
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
                            content: 'هل تريد بالتأكيد حذف عملية "${item.title}"؟',
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditTransactionScreen(
                initialCurrency: _selectedCurrencyFilter,
              ),
            ),
          );
        },
        tooltip: 'إضافة عملية جديدة',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildTypeFilterChip({
    required String label,
    Color color = AppColors.primaryTeal,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
