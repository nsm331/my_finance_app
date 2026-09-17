import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/security_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/category_provider.dart';
import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../services/auto_sync_service.dart';
import '../widgets/confirm_dialog.dart';
import '../core/constants/app_colors.dart';
import 'pin_lock_screen.dart';
import 'change_pin_screen.dart';
import 'currency_exchange_screen.dart';
import 'recurring_transactions_screen.dart';
import 'wallets_screen.dart';
import 'auth/login_screen.dart';
import '../widgets/transfer_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _lastBackupDate;
  String? _lastCloudSyncDate;
  bool _autoBackupEnabled = true;
  bool _autoCloudSyncEnabled = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isCloudSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final backupService = BackupService();
    final date = await backupService.getLastBackupDate();
    final autoEnabled = await backupService.isAutoBackupEnabled();
    final syncDate = await CloudSyncService().getLastSyncDate();
    final autoCloud = await AutoSyncService.instance.isAutoSyncEnabled();
    if (mounted) {
      setState(() {
        _lastBackupDate = date;
        _autoBackupEnabled = autoEnabled;
        _lastCloudSyncDate = syncDate;
        _autoCloudSyncEnabled = autoCloud;
      });
    }
  }

  Future<void> _exportBackup() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);

    try {
      final backupService = BackupService();
      final result = await backupService.exportDatabaseBackup();

      if (mounted) {
        if (result.success) {
          await _loadSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.income,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else if (result.savedPath != null || result.message != 'تم إلغاء عملية النسخ الاحتياطي') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء النسخ الاحتياطي: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_isRestoring) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'استعادة قاعدة البيانات (.db)',
      content:
          'تنبيه هام جداً: سيتم استبدال كافة البيانات والعمليات والديون الحالية بقاعدة البيانات المختارة من النسخة الاحتياطية. هل ترغب بالمتابعة؟',
      confirmLabel: 'متابعة واختيار الملف',
      confirmColor: AppColors.primaryTeal,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      final backupService = BackupService();
      final result = await backupService.restoreDatabaseBackup();

      if (!mounted) return;

      if (result.success) {
        // Reload all providers with fresh data from the newly restored SQLite database
        final finance = Provider.of<FinanceProvider>(context, listen: false);
        final debt = Provider.of<DebtProvider>(context, listen: false);
        final category = Provider.of<CategoryProvider>(context, listen: false);

        await Future.wait([
          finance.loadAllData(),
          debt.loadAll(),
          category.loadCategories(),
        ]);

        await _loadSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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
      } else if (result.message != 'تم إلغاء اختيار الملف') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل استعادة قاعدة البيانات: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'تحذير شديد: مسح جميع البيانات',
      content:
          'هل أنت متأكد تماماً من رغبتك في حذف جميع العمليات والديون والمحافظ والتصنيفات من قاعدة البيانات؟ لا يمكن التراجع عن هذه الخطوة إطلاقاً!',
      confirmLabel: 'نعم، احذف كل شيء',
      confirmColor: AppColors.expense,
    );

    if (!confirmed || !mounted) return;

    try {
      await DatabaseHelper.instance.clearAllData();

      if (mounted) {
        final finance = Provider.of<FinanceProvider>(context, listen: false);
        final debt = Provider.of<DebtProvider>(context, listen: false);
        final category = Provider.of<CategoryProvider>(context, listen: false);

        await Future.wait([
          finance.loadAllData(),
          debt.loadAll(),
          category.loadCategories(),
        ]);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'تم مسح كافة البيانات بنجاح وإعادة ضبط التطبيق',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء مسح البيانات: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _uploadToCloud() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً للتمكن من رفع البيانات إلى السحابة'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_isCloudSyncing) return;
    setState(() => _isCloudSyncing = true);

    try {
      final syncService = CloudSyncService();
      final result = await syncService.uploadLocalDataToCloud(authProvider.userId!);

      if (mounted) {
        if (result.success) {
          final date = await syncService.getLastSyncDate();
          if (!mounted) return;
          setState(() {
            _lastCloudSyncDate = date;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.income,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء رفع البيانات: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCloudSyncing = false);
      }
    }
  }

  Future<void> _downloadFromCloud() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً للتمكن من استعادة البيانات من السحابة'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'استعادة البيانات من السحابة',
      content:
          'تحذير: ستؤدي هذه العملية إلى استبدال كافة البيانات المحلية الحالية بالبيانات المحفوظة في السحابة لهذا الحساب. هل ترغب بالاستمرار؟',
      confirmLabel: 'استعادة الآن',
      confirmColor: AppColors.sarColor,
    );

    if (!confirmed) return;

    if (_isCloudSyncing) return;
    setState(() => _isCloudSyncing = true);

    try {
      final syncService = CloudSyncService();
      final result = await syncService.downloadCloudDataToLocal(authProvider.userId!);

      if (mounted) {
        if (result.success) {
          final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
          final debtProvider = Provider.of<DebtProvider>(context, listen: false);
          final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

          await Future.wait([
            financeProvider.loadAllData(),
            debtProvider.loadAll(),
            categoryProvider.loadCategories(),
          ]);

          final date = await syncService.getLastSyncDate();
          if (!mounted) return;
          setState(() {
            _lastCloudSyncDate = date;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.income,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء استعادة البيانات: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCloudSyncing = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'تسجيل الخروج',
      content: 'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك السحابي؟',
      confirmLabel: 'تسجيل خروج',
      confirmColor: AppColors.expense,
    );
    if (confirmed) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الخروج بنجاح'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  /// Exits Guest Mode and returns to LoginScreen
  Future<void> _exitGuestMode() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'خروج من وضع الضيف',
      content:
          'سيتم إعادتك إلى شاشة تسجيل الدخول. بيانات وضع الضيف المحلية ستظل محفوظة على الجهاز. هل ترغب بالمتابعة؟',
      confirmLabel: 'خروج وتسجيل الدخول',
      confirmColor: AppColors.primaryTeal,
    );
    if (!confirmed || !mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.exitGuestMode();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildCloudSyncCard(BuildContext context, bool isDark) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAuthenticated = authProvider.isAuthenticated;
    final isGuest = authProvider.isGuestMode;
    final userEmail = authProvider.userEmail;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // ── GUEST MODE ── show warning banner + exit button only
          if (isGuest) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 26),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'المزامنة السحابية غير متاحة في وضع الضيف. يرجى إنشاء حساب لحماية بياناتك.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Guest mode indicator chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              'وضع الضيف — تخزين محلي فقط',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Exit Guest Mode / Login Button
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _exitGuestMode,
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        'خروج من وضع الضيف / تسجيل الدخول',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── NOT AUTHENTICATED (but not guest) ── show login prompt
          ] else if (!isAuthenticated) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      size: 36,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'المزامنة السحابية غير مفعلة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'قم بتسجيل الدخول أو إنشاء حساب جديد لحفظ كافة بياناتك المالية على السحابة واستعادتها بسهولة على أي جهاز.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text(
                        'تسجيل الدخول / إنشاء حساب',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── AUTHENTICATED ── full cloud sync controls
          ] else ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                        child: const Icon(Icons.person_rounded, color: AppColors.primaryTeal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userEmail != null && userEmail.isNotEmpty ? userEmail : 'مستخدم السحابة',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.income,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'متصل بالسحابة بأمان',
                                  style: TextStyle(fontSize: 11, color: AppColors.income, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        tooltip: 'تسجيل الخروج',
                        icon: const Icon(Icons.logout_rounded, color: AppColors.expense, size: 20),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 16, color: AppColors.primaryTeal),
                      const SizedBox(width: 6),
                      Text(
                        'آخر مزامنة: ${_lastCloudSyncDate != null && _lastCloudSyncDate!.isNotEmpty ? _lastCloudSyncDate! : "لم تتم المزامنة بعد"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: AutoSyncService.instance.isSyncingNotifier,
                    builder: (context, isAutoSyncing, _) {
                      if (!isAutoSyncing) return const SizedBox.shrink();
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'جاري المزامنة التلقائية عبر الإنترنت الآن...',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryTeal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Switch: Auto Sync on Internet Connection
            SwitchListTile(
              title: const Text('المزامنة التلقائية عند الاتصال بالإنترنت'),
              subtitle: Text(
                'رفع وتحديث بياناتك على السحابة تلقائياً بمجرد فتح النت أو توفر الشبكة',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              secondary: const Icon(Icons.sync_rounded, color: AppColors.primaryTeal),
              value: _autoCloudSyncEnabled,
              onChanged: (val) async {
                await AutoSyncService.instance.setAutoSyncEnabled(val);
                setState(() => _autoCloudSyncEnabled = val);
                if (val) {
                  await AutoSyncService.instance.checkConnectivityAndSync();
                  final syncDate = await CloudSyncService().getLastSyncDate();
                  if (mounted) {
                    setState(() => _lastCloudSyncDate = syncDate);
                  }
                }
              },
            ),

            ValueListenableBuilder<({bool? success, String? message})>(
              valueListenable: AutoSyncService.instance.syncResultNotifier,
              builder: (context, result, _) {
                if (result.message == null) return const SizedBox.shrink();
                final isSuccess = result.success == true;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isSuccess ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isSuccess ? AppColors.income : AppColors.expense).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                        size: 18,
                        color: isSuccess ? AppColors.income : AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.message!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSuccess ? AppColors.income : AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

            ListTile(
              leading: _isCloudSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                    )
                  : const Icon(Icons.cloud_upload_rounded, color: AppColors.primaryTeal),
              title: const Text(
                'رفع وتحديث البيانات إلى السحابة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'حفظ جميع العمليات والديون والمحافظ والتصنيفات في قاعدة بيانات Firestore السحابية',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: _isCloudSyncing ? null : _uploadToCloud,
            ),
            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ListTile(
              leading: _isCloudSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sarColor),
                    )
                  : const Icon(Icons.cloud_download_rounded, color: AppColors.sarColor),
              title: const Text(
                'استعادة البيانات من السحابة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'تنزيل آخر نسخة سحابية واستبدال البيانات المحلية وتحديث كافة الشاشات فوراً',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: _isCloudSyncing ? null : _downloadFromCloud,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 8, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryTeal),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final securityProvider = Provider.of<SecurityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والبيانات'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Theme Section
          _buildSectionHeader(context, 'المظهر والثيم', Icons.palette_outlined),
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: RadioGroup<ThemeMode>(
              groupValue: themeProvider.themeMode,
              onChanged: (val) {
                if (val != null) themeProvider.setThemeMode(val);
              },
              child: Column(
                children: [
                  const RadioListTile<ThemeMode>(
                    title: Text('الوضع الفاتح'),
                    secondary: Icon(Icons.light_mode_rounded, color: Colors.amber),
                    value: ThemeMode.light,
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  const RadioListTile<ThemeMode>(
                    title: Text('الوضع الداكن'),
                    secondary: Icon(Icons.dark_mode_rounded, color: AppColors.usdColor),
                    value: ThemeMode.dark,
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  const RadioListTile<ThemeMode>(
                    title: Text('تلقائي حسب إعدادات النظام'),
                    secondary: Icon(Icons.brightness_auto_rounded),
                    value: ThemeMode.system,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Security & PIN Section
          _buildSectionHeader(context, 'الأمان وقفل التطبيق', Icons.security_rounded),
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('قفل التطبيق برمز مرور (PIN)'),
                  subtitle: Text(
                    securityProvider.isPinSet
                        ? 'رمز المرور مفعل لحماية بياناتك المالية'
                        : 'لم يتم تعيين رمز مرور بعد',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  secondary: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryTeal),
                  value: securityProvider.isAppLockEnabled,
                  onChanged: (val) async {
                    if (val) {
                      if (!securityProvider.isPinSet) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PinLockScreen(mode: PinScreenMode.setupNew),
                          ),
                        );
                      } else {
                        await securityProvider.toggleAppLock(true);
                      }
                    } else {
                      await securityProvider.toggleAppLock(false);
                    }
                  },
                ),
                if (securityProvider.isPinSet) ...[
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  SwitchListTile(
                    title: const Text('فتح القفل بالبصمة (Biometrics)'),
                    subtitle: Text(
                      securityProvider.isBiometricSupported
                          ? 'استخدام بصمة الإصبع أو الوجه لفتح التطبيق بسرعة'
                          : 'البصمة غير متوفرة أو غير مفعلة في إعدادات جهازك',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryTeal),
                    value: securityProvider.isBiometricEnabled,
                    onChanged: (val) async {
                      if (!securityProvider.isBiometricSupported) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('البصمة غير مدعومة أو لم يتم تسجيل أي بصمة في الهاتف'),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                        return;
                      }
                      if (val) {
                        final authSuccess = await securityProvider.authenticateWithBiometrics();
                        if (authSuccess) {
                          await securityProvider.toggleBiometric(true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تفعيل الفتح بالبصمة بنجاح'),
                                backgroundColor: AppColors.income,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            final err = securityProvider.lastAuthError ?? 'فشل التحقق من البصمة، لم يتم التفعيل';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                          }
                        }
                      } else {
                        await securityProvider.toggleBiometric(false);
                      }
                    },
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ListTile(
                    leading: const Icon(Icons.password_rounded, color: AppColors.primaryTeal),
                    title: const Text('تغيير رمز المرور (PIN)'),
                    subtitle: Text(
                      'تعيين رمز حماية سري جديد مكون من 4 أرقام',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePinScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ListTile(
                    leading: const Icon(Icons.lock_open_rounded, color: AppColors.expense),
                    title: const Text('إلغاء وإزالة رمز المرور', style: TextStyle(color: AppColors.expense)),
                    subtitle: Text(
                      'حذف رمز PIN وإلغاء القفل بالكامل عن التطبيق',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    onTap: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'إلغاء رمز الأمان',
                        content: 'هل أنت متأكد من رغبتك في إزالة رمز PIN؟ سيتم فتح التطبيق مباشرة دون قفل.',
                        confirmLabel: 'إزالة الرمز',
                        confirmColor: AppColors.expense,
                      );
                      if (confirmed) {
                        await securityProvider.removePin();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت إزالة رمز المرور بنجاح'),
                              backgroundColor: AppColors.income,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Backup & Restore Section (.db SQLite)
          _buildSectionHeader(context, 'النسخ الاحتياطي لقاعدة البيانات (.db)', Icons.storage_rounded),
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                // Info Box: Last Backup Date
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: isDark ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_rounded, size: 20, color: AppColors.primaryTeal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حالة النسخ الاحتياطي',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'آخر نسخة احتياطية: ${_lastBackupDate != null && _lastBackupDate!.isNotEmpty ? _lastBackupDate! : "لم يتم أخذ نسخة بعد"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_lastBackupDate != null)
                        const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 18),
                    ],
                  ),
                ),

                // Switch: Daily Auto Backup
                SwitchListTile(
                  title: const Text('النسخ الاحتياطي التلقائي اليومي'),
                  subtitle: Text(
                    'حفظ نسخة احتياطية محلية تلقائياً في مجلد Documents/ميزانيتي',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  secondary: const Icon(Icons.autorenew_rounded, color: AppColors.primaryTeal),
                  value: _autoBackupEnabled,
                  onChanged: (val) async {
                    final backupService = BackupService();
                    await backupService.setAutoBackupEnabled(val);
                    setState(() => _autoBackupEnabled = val);
                    if (val) {
                      await backupService.checkAndRunDailyBackup();
                      await _loadSettings();
                    }
                  },
                ),

                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

                // Button: Export .db
                ListTile(
                  leading: _isBackingUp
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                        )
                      : const Icon(Icons.cloud_upload_rounded, color: AppColors.primaryTeal),
                  title: const Text(
                    'إنشاء نسخة احتياطية (.db)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'تصدير ملف قاعدة بيانات SQLite وحفظه أو مشاركته بأمان',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.save_alt_rounded, size: 22, color: AppColors.primaryTeal),
                  onTap: _isBackingUp ? null : _exportBackup,
                ),

                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

                // Button: Restore .db
                ListTile(
                  leading: _isRestoring
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sarColor),
                        )
                      : const Icon(Icons.settings_backup_restore_rounded, color: AppColors.sarColor),
                  title: const Text(
                    'استعادة نسخة احتياطية (.db)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'اختيار ملف .db واستبدال البيانات وإعادة تحميل كافة السجلات',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.folder_open_rounded, size: 22, color: AppColors.sarColor),
                  onTap: _isRestoring ? null : _restoreBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Cloud Sync Section (Firebase Firestore)
          _buildSectionHeader(context, 'المزامنة السحابية (Cloud Sync)', Icons.cloud_sync_rounded),
          _buildCloudSyncCard(context, isDark),

          const SizedBox(height: 16),

          // 5. Financial Tools Section
          _buildSectionHeader(context, 'الأدوات والمحافظ المالية', Icons.account_balance_wallet_rounded),
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded, color: AppColors.sarColor),
                  title: const Text('حاسبة تحويل العملات والصرافة'),
                  subtitle: Text(
                    'حساب تحويل المبالغ بين الريال اليمني والسعودي والدولار فورياً',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CurrencyExchangeScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ListTile(
                  leading: const Icon(Icons.event_repeat_rounded, color: AppColors.primaryTeal),
                  title: const Text('العمليات المجدولة والمتكررة'),
                  subtitle: Text(
                    'إدارة المصاريف والدخول الثابتة شهرياً (إيجار، اشتراكات، رواتب)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecurringTransactionsScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryTeal),
                  title: const Text('إدارة المحافظ والحسابات'),
                  subtitle: Text(
                    'تعديل المحافظ وحسابات البنوك، تخصيص الألوان والأيقونات',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WalletsScreen(),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ListTile(
                  leading: const Icon(Icons.sync_alt_rounded, color: Color(0xFF0284C7)),
                  title: const Text('تحويل الأموال بين المحافظ'),
                  subtitle: Text(
                    'إجراء تحويل مالي فوري بين محفظتين بنفس العملة',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  onTap: () => TransferSheet.show(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Dangerous Data Reset Section
          _buildSectionHeader(context, 'إدارة البيانات وإعادة الضبط', Icons.warning_amber_rounded),
          Card(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.expense.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.expense, size: 24),
              ),
              title: const Text(
                'مسح جميع البيانات وإعادة التعيين',
                style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'حذف كافة العمليات والديون والمحافظ وإعادة ضبط قاعدة البيانات للحالة الأولية',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.expense),
              onTap: _clearAllData,
            ),
          ),

          const SizedBox(height: 24),

          // 6. About App Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 52,
                    height: 52,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 48,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تطبيق ميزانيتي',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الإصدار 1.0.0 (قاعدة بيانات SQLite)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تطبيق مالي شخصي يعمل بدون إنترنت (Offline-First)\nيدعم العملات الثلاث وتعدد المحافظ وسجل الذمم والديون',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
