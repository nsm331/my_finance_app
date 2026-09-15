import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_finance_app/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService Settings & Preferences Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isAutoBackupEnabled defaults to true', () async {
      final service = BackupService();
      final enabled = await service.isAutoBackupEnabled();
      expect(enabled, isTrue);
    });

    test('setAutoBackupEnabled persists state', () async {
      final service = BackupService();
      await service.setAutoBackupEnabled(false);
      expect(await service.isAutoBackupEnabled(), isFalse);

      await service.setAutoBackupEnabled(true);
      expect(await service.isAutoBackupEnabled(), isTrue);
    });

    test('getLastBackupDate returns null when no backup made', () async {
      final service = BackupService();
      final lastDate = await service.getLastBackupDate();
      expect(lastDate, isNull);
    });

    test('getLastBackupDate returns saved timestamp', () async {
      SharedPreferences.setMockInitialValues({
        BackupService.keyLastBackupDate: '2026-09-15 14:00',
      });
      final service = BackupService();
      final lastDate = await service.getLastBackupDate();
      expect(lastDate, '2026-09-15 14:00');
    });

    test('androidDedicatedBackupPath is correctly targeted to Documents/ميزانيتي', () {
      expect(BackupService.androidDedicatedBackupPath, '/storage/emulated/0/Documents/ميزانيتي');
    });
  });
}
