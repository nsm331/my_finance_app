import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/security_provider.dart';
import '../services/backup_service.dart';
import '../core/constants/app_colors.dart';
import '../widgets/custom_drawer.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'debts_screen.dart';
import 'categories_budget_screen.dart';
import 'wallets_screen.dart';
import 'add_edit_transaction_screen.dart';
import 'add_edit_debt_screen.dart';
import 'pin_lock_screen.dart';
import '../widgets/transfer_sheet.dart';
import '../services/cloud_sync_service.dart';
import '../services/guest_service.dart';
import '../providers/finance_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/category_provider.dart';
import '../services/pdf_report_service.dart';
import '../core/utils/date_formatter.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRunDailyBackup();
    _initRealTimeSync();
  }

  Future<void> _initRealTimeSync() async {
    final isGuest = await GuestService.isGuestMode();
    if (!isGuest && mounted) {
      CloudSyncService().startRealTimeListeners(onDataChanged: () {
        if (mounted) {
          context.read<FinanceProvider>().loadAllData();
          context.read<DebtProvider>().loadAll();
          context.read<CategoryProvider>().loadCategories();
        }
      });
    }
  }

  Future<void> _checkAndRunDailyBackup() async {
    try {
      final backupService = BackupService();
      final didBackup = await backupService.checkAndRunDailyBackup();
      if (didBackup && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'تم أخذ نسخة احتياطية يومية بنجاح 💾',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MainNavigationScreen] Daily auto-backup error: $e');
    }
  }

  @override
  void dispose() {
    CloudSyncService().stopRealTimeListeners();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    final securityProvider = Provider.of<SecurityProvider>(context, listen: false);

    // تجاهل تام لأي حدث دورة حياة أثناء المصادقة أو فور نجاحها (براءة ذمة لمدة ثانيتين ونصف)
    if (securityProvider.isAuthenticating || securityProvider.recentlyAuthenticated) {
      return;
    }

    // تتبع مغادرة التطبيق إلى الخلفية فعلياً
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground) {
        _wasInBackground = false;
        if (securityProvider.isPinSet &&
            securityProvider.isAppLockEnabled &&
            !securityProvider.isLocked) {
          securityProvider.lockApp();
        }
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'لوحة التحكم المالية';
      case 1:
        return 'سجل العمليات المالية';
      case 2:
        return 'إدارة الديون وسجل الأشخاص';
      case 3:
        return 'الميزانية والتصنيفات';
      case 4:
        return 'إدارة المحافظ والحسابات';
      default:
        return 'ميزانيتي';
    }
  }

  List<Widget> _getAppBarActions(int index) {
    switch (index) {
      case 0:
      case 4:
        return [
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded),
            tooltip: 'تحويل بين المحافظ',
            onPressed: () => TransferSheet.show(context),
          ),
        ];
      case 3:
        return [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'تصدير التقرير الشهري PDF',
            onPressed: () {
              final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
              final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
              final now = DateTime.now();
              final filename = 'التقرير_المالي_الشهري_${now.year}_${now.month}.pdf';
              PdfReportService.showReportModal(
                context,
                title: 'التقرير المالي الشهري (${DateFormatter.formatMonthYear(now)})',
                filename: filename,
                onGenerateBytes: () => PdfReportService.generateMonthlyReportBytes(
                  month: now,
                  allTransactions: financeProvider.transactions,
                  categories: categoryProvider.categories,
                ),
              );
            },
          ),
        ];
      default:
        return [];
    }
  }

  Future<void> _showExitConfirmationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.exit_to_app_rounded, color: AppColors.expense),
              SizedBox(width: 8),
              Text('الخروج من التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'هل تريد الخروج من التطبيق؟',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  void _showAddSpeedDial() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'إضافة جديدة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'إضافة مصروف',
                    color: AppColors.expense,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditTransactionScreen(initialIsExpense: true),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'إضافة دخل',
                    color: AppColors.income,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditTransactionScreen(initialIsExpense: false),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.handshake_outlined,
                    label: 'تسجيل دين',
                    color: AppColors.sarColor,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEditDebtScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.sync_alt_rounded,
                    label: 'تحويل بين المحافظ',
                    color: AppColors.primaryTeal,
                    onTap: () {
                      Navigator.pop(ctx);
                      TransferSheet.show(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final securityProvider = Provider.of<SecurityProvider>(context);

    // If app lock is enabled and currently locked, show PIN lock gate
    if (securityProvider.isLocked) {
      return const PinLockScreen(mode: PinScreenMode.unlock);
    }

    final screens = [
      DashboardScreen(
        onNavigateToTransactions: () => _onTabSelected(1),
        onNavigateToDebts: () => _onTabSelected(2),
        onNavigateToWallets: () => _onTabSelected(4),
      ),
      const TransactionsScreen(),
      const DebtsScreen(),
      const CategoriesBudgetScreen(isEmbedded: true),
      const WalletsScreen(isEmbedded: true),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          await _showExitConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle(_currentIndex)),
          actions: _getAppBarActions(_currentIndex),
        ),
        drawer: CustomDrawer(
          onNavigateToDashboard: () => _onTabSelected(0),
          onNavigateToWallets: () => _onTabSelected(4),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'العمليات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.handshake_rounded),
              label: 'الديون',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_rounded),
              label: 'الميزانية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: 'المحافظ',
            ),
          ],
        ),
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton(
                onPressed: _showAddSpeedDial,
                tooltip: 'إضافة جديدة',
                child: const Icon(Icons.add_rounded, size: 28),
              )
            : null,
      ),
    );
  }
}
