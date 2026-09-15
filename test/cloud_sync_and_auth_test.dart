import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_finance_app/services/auth_service.dart';
import 'package:my_finance_app/services/cloud_sync_service.dart';
import 'package:my_finance_app/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Arabic Error Mapping Tests', () {
    test('Translates common FirebaseAuth error codes to clear Arabic messages', () {
      expect(
        AuthService.getArabicErrorMessage('user-not-found'),
        'لا يوجد حساب مسجل بهذا البريد الإلكتروني',
      );
      expect(
        AuthService.getArabicErrorMessage('wrong-password'),
        'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً',
      );
      expect(
        AuthService.getArabicErrorMessage('email-already-in-use'),
        'هذا البريد الإلكتروني مسجل بالفعل لحساب آخر',
      );
      expect(
        AuthService.getArabicErrorMessage('network-request-failed'),
        'تعذر الاتصال بالشبكة، يرجى التحقق من اتصال الإنترنت',
      );
      expect(
        AuthService.getArabicErrorMessage('weak-password'),
        'كلمة المرور ضعيفة جداً، يرجى استخدام 6 أحرف على الأقل',
      );
      expect(
        AuthService.getArabicErrorMessage('unknown-error-code'),
        contains('unknown-error-code'),
      );
    });
  });

  group('CloudSyncService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getLastSyncDate returns null initially', () async {
      final syncService = CloudSyncService();
      final lastDate = await syncService.getLastSyncDate();
      expect(lastDate, isNull);
    });

    test('Returns graceful error message when no user is authenticated', () async {
      final syncService = CloudSyncService();
      final uploadResult = await syncService.uploadLocalDataToCloud();
      expect(uploadResult.success, isFalse);
      expect(uploadResult.totalUploaded, 0);

      final downloadResult = await syncService.downloadCloudDataToLocal();
      expect(downloadResult.success, isFalse);
      expect(downloadResult.totalDownloaded, 0);
    });
  });

  group('DatabaseHelper Version 3 Multi-User Schema Tests', () {
    test('Active user ID can be set and read', () {
      final dbHelper = DatabaseHelper.instance;
      expect(dbHelper.activeUserId, isNull);

      dbHelper.setActiveUserId('test_firebase_uid_123');
      expect(dbHelper.activeUserId, 'test_firebase_uid_123');

      dbHelper.setActiveUserId(null);
      expect(dbHelper.activeUserId, isNull);
    });

    test('Table constants and column constants are well-defined', () {
      expect(DatabaseHelper.tableWallets, 'wallets');
      expect(DatabaseHelper.tableTransactions, 'transactions');
      expect(DatabaseHelper.tablePersons, 'persons');
      expect(DatabaseHelper.tableDebts, 'debts');
      expect(DatabaseHelper.tableCategories, 'categories');
      expect(DatabaseHelper.tableRecurring, 'recurring_transactions');
      expect(DatabaseHelper.colUserId, 'user_id');
    });
  });
}
