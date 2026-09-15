import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/security_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/category_provider.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../widgets/confirm_dialog.dart';
import '../core/constants/app_colors.dart';
import 'pin_lock_screen.dart';
import 'change_pin_screen.dart';
import 'currency_exchange_screen.dart';
import 'recurring_transactions_screen.dart';
import 'wallets_screen.dart';
import '../widgets/transfer_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _lastBackupDate;
  bool _autoBackupEnabled = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final backupService = BackupService();
    final date = await backupService.getLastBackupDate();
    final autoEnabled = await backupService.isAutoBackupEnabled();
    if (mounted) {
      setState(() {
        _lastBackupDate = date;
        _autoBackupEnabled = autoEnabled;
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

          // 4. Financial Tools Section
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
