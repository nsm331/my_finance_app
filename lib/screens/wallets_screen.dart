import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/icon_helper.dart';
import '../widgets/transfer_sheet.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  Future<void> _showWalletFormSheet({WalletModel? walletToEdit}) async {
    final isEditing = walletToEdit != null;
    final nameController = TextEditingController(text: walletToEdit?.name ?? '');
    final formKey = GlobalKey<FormState>();

    Color selectedColor = walletToEdit != null ? walletToEdit.color : AppColors.primaryTeal;
    IconData selectedIcon = walletToEdit != null
        ? walletToEdit.iconData
        : Icons.account_balance_wallet_rounded;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 25,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selectedColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                                color: selectedColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isEditing ? 'تعديل بيانات المحفظة' : 'إضافة محفظة أو حساب جديد',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Live Preview Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selectedColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selectedColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selectedColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  selectedIcon,
                                  color: selectedColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameController.text.trim().isEmpty
                                          ? 'اسم المحفظة'
                                          : nameController.text.trim(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: nameController.text.trim().isEmpty
                                            ? Colors.grey
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'معاينة حية للمحفظة',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: selectedColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name Field
                        TextFormField(
                          controller: nameController,
                          autofocus: !isEditing,
                          decoration: InputDecoration(
                            labelText: 'اسم المحفظة / الحساب',
                            hintText: 'مثال: محفظة جيب، بنك الكريمي، فيزا...',
                            prefixIcon: Icon(selectedIcon, color: selectedColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'الرجاء إدخال اسم المحفظة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Color Picker
                        const Text(
                          'لون المحفظة المميز',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: AppIcons.availableWalletColors.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final color = AppIcons.availableWalletColors[index];
                              final isSelected = selectedColor.toARGB32() == color.toARGB32();

                              return GestureDetector(
                                onTap: () => setModalState(() => selectedColor = color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: Colors.white, width: 3)
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Icon Picker
                        const Text(
                          'أيقونة المحفظة',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: AppIcons.availableWalletIcons.map((icon) {
                            final isSelected = selectedIcon.codePoint == icon.codePoint;

                            return InkWell(
                              onTap: () => setModalState(() => selectedIcon = icon),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.18)
                                      : (isDark ? AppColors.darkBackground : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? selectedColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? selectedColor
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  size: 24,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
                            final name = nameController.text.trim();

                            try {
                              if (isEditing) {
                                await financeProvider.updateWallet(
                                  walletToEdit.copyWith(
                                    name: name,
                                    iconCode: selectedIcon.codePoint,
                                    colorValue: selectedColor.toARGB32(),
                                  ),
                                );
                              } else {
                                await financeProvider.addWallet(
                                  name,
                                  iconCode: selectedIcon.codePoint,
                                  colorValue: selectedColor.toARGB32(),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ: $e'),
                                    backgroundColor: AppColors.expense,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            isEditing ? 'حفظ التعديلات' : 'إضافة المحفظة',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'تم تحديث بيانات المحفظة بنجاح 💼' : 'تمت إضافة المحفظة بنجاح 💼',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showDeleteWalletDialog(WalletModel wallet) async {
    final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
    if (financeProvider.wallets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف هذه المحفظة لأنها المحفظة الوحيدة في التطبيق'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.expense),
              SizedBox(width: 8),
              Text('حذف المحفظة', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف محفظة "${wallet.name}"؟\nستبقى العمليات المرتبطة بها محفوظة في النظام.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && wallet.id != null) {
      await financeProvider.deleteWallet(wallet.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف محفظة "${wallet.name}" بنجاح'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financeProvider = Provider.of<FinanceProvider>(context);
    final wallets = financeProvider.wallets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المحافظ والحسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded),
            tooltip: 'تحويل بين المحافظ',
            onPressed: () => TransferSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'إضافة محفظة',
            onPressed: () => _showWalletFormSheet(),
          ),
        ],
      ),
      body: wallets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد محافظ مسجلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showWalletFormSheet(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة محفظة الآن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: wallets.length,
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                final balances = financeProvider.getWalletBalances(wallet.id ?? -1);

                return _buildWalletCard(
                  context: context,
                  wallet: wallet,
                  balances: balances,
                  isDark: isDark,
                  financeProvider: financeProvider,
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          border: Border(
            top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showWalletFormSheet(),
                icon: const Icon(Icons.add_rounded, color: AppColors.primaryTeal),
                label: const Text(
                  'محفظة جديدة',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primaryTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => TransferSheet.show(context),
                icon: const Icon(Icons.sync_alt_rounded, color: Colors.white),
                label: const Text(
                  'تحويل بين المحافظ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard({
    required BuildContext context,
    required WalletModel wallet,
    required Map<AppCurrency, double> balances,
    required bool isDark,
    required FinanceProvider financeProvider,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: wallet.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: wallet.color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    wallet.iconData,
                    color: wallet.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'معرف المحفظة: #${wallet.id ?? 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showWalletFormSheet(walletToEdit: wallet);
                    } else if (action == 'delete') {
                      _showDeleteWalletDialog(wallet);
                    } else if (action == 'transfer_from') {
                      TransferSheet.show(context, initialFromWalletId: wallet.id);
                    } else if (action == 'transfer_to') {
                      TransferSheet.show(context, initialToWalletId: wallet.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'transfer_from',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.expense),
                          SizedBox(width: 8),
                          Text('تحويل من هذه المحفظة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'transfer_to',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 18, color: AppColors.income),
                          SizedBox(width: 8),
                          Text('تحويل إلى هذه المحفظة'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryTeal),
                          SizedBox(width: 8),
                          Text('تعديل المحفظة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                          SizedBox(width: 8),
                          Text('حذف المحفظة'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Balances Section
            const Text(
              'الأرصدة المتوفرة بالمحفظة:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            if (balances.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      'الرصيد: 0.00 (لا توجد عمليات مسجلة)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: balances.entries.map((entry) {
                  final currency = entry.key;
                  final balance = entry.value;
                  final isPositive = balance >= 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currency.primaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currency.primaryColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currency.icon, size: 16, color: currency.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          '${currency.nameAr}: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: currency.primaryColor,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(balance, currency),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isPositive
                                ? (isDark ? Colors.white : Colors.black87)
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
