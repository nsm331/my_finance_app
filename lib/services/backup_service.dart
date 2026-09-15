import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class BackupService {
  static const String keyLastBackupDate = 'last_backup_date';
  static const String keyLastAutoBackupDate = 'last_auto_backup_date';
  static const String keyAutoBackupEnabled = 'auto_backup_enabled';

  final DatabaseHelper _dbHelper;

  BackupService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Exports the live SQLite database file (.db) to user storage or share sheet
  Future<({bool success, String message, String? savedPath})> exportDatabaseBackup() async {
    try {
      final dbPath = await _dbHelper.getDatabaseFilePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists() || await dbFile.length() == 0) {
        return (
          success: false,
          message: 'ملف قاعدة البيانات غير موجود أو فارغ',
          savedPath: null,
        );
      }

      final dateStr = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final fileName = 'my_finance_backup_$dateStr.db';
      final fileBytes = await dbFile.readAsBytes();

      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ نسخة احتياطية (.db)',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['db', 'sqlite'],
          bytes: fileBytes,
        );
      } catch (e) {
        debugPrint('[BackupService] saveFile error or unsupported platform: $e');
      }

      // If user saved directly to a chosen location
      if (outputFile != null && outputFile.isNotEmpty) {
        final dest = File(outputFile);
        if (!await dest.exists() || await dest.length() == 0) {
          await dest.writeAsBytes(fileBytes);
        }
        await _recordBackupSuccess();
        return (
          success: true,
          message: 'تم حفظ النسخة الاحتياطية بنجاح:\n$outputFile',
          savedPath: outputFile,
        );
      }

      // Fallback: Copy to temporary cache and share via native share sheet
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(join(tempDir.path, fileName));
      await tempFile.writeAsBytes(fileBytes);

      final xFile = XFile(
        tempFile.path,
        name: fileName,
        mimeType: 'application/octet-stream',
      );

      final shareResult = await Share.shareXFiles(
        [xFile],
        subject: 'نسخة احتياطية - تطبيق ميزانيتي (.db)',
        text: 'ملف قاعدة بيانات ميزانيتي ($fileName)',
      );

      final isShared = shareResult.status == ShareResultStatus.success ||
          shareResult.status == ShareResultStatus.dismissed;

      if (isShared) {
        await _recordBackupSuccess();
        return (
          success: true,
          message: 'تمت مشاركة وتصدير النسخة الاحتياطية بنجاح',
          savedPath: tempFile.path,
        );
      }

      return (
        success: false,
        message: 'تم إلغاء عملية النسخ الاحتياطي',
        savedPath: null,
      );
    } catch (e, stack) {
      debugPrint('[BackupService] Error exporting database backup: $e\n$stack');
      return (
        success: false,
        message: 'حدث خطأ أثناء تصدير النسخة الاحتياطية: $e',
        savedPath: null,
      );
    }
  }

  /// Restores the SQLite database from a user-selected .db file
  Future<({bool success, String message})> restoreDatabaseBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return (success: false, message: 'تم إلغاء اختيار الملف');
      }

      final selectedPath = result.files.single.path!;
      final selectedFile = File(selectedPath);

      // Verify extension is .db or .sqlite
      final ext = extension(selectedPath).toLowerCase();
      if (ext != '.db' && ext != '.sqlite' && ext != '.sqlite3') {
        return (
          success: false,
          message: 'الملف المختار غير صالح. يرجى اختيار ملف بامتداد .db',
        );
      }

      if (!await selectedFile.exists() || await selectedFile.length() == 0) {
        return (
          success: false,
          message: 'الملف المختار فارغ أو تالف',
        );
      }

      // Crucial: Close current database before replacing the file
      await _dbHelper.close();

      final currentDbPath = await _dbHelper.getDatabaseFilePath();
      final currentDbFile = File(currentDbPath);

      // Create a safety backup (.bak) of the current database before replacing
      final backupSafetyPath = '$currentDbPath.bak';
      if (await currentDbFile.exists()) {
        await currentDbFile.copy(backupSafetyPath);
      }

      try {
        // Copy the chosen file to replace current SQLite database
        await selectedFile.copy(currentDbPath);

        // Re-open and verify database integrity
        final db = await _dbHelper.database;
        final integrityCheck = await db.rawQuery('PRAGMA integrity_check');
        final isOk = integrityCheck.isNotEmpty &&
            integrityCheck.first.values.first.toString().toLowerCase() == 'ok';

        if (!isOk) {
          throw Exception('فشل فحص سلامة قاعدة البيانات المسترجعة');
        }

        // Clean up safety backup on success
        final safetyFile = File(backupSafetyPath);
        if (await safetyFile.exists()) {
          await safetyFile.delete();
        }

        await _recordBackupSuccess();

        return (
          success: true,
          message: 'تمت استعادة قاعدة البيانات بنجاح وتحديث كافة السجلات!',
        );
      } catch (innerError) {
        // Rollback from safety backup
        final safetyFile = File(backupSafetyPath);
        if (await safetyFile.exists()) {
          await safetyFile.copy(currentDbPath);
          await safetyFile.delete();
        }
        await _dbHelper.database; // Reconnect original db
        rethrow;
      }
    } catch (e, stack) {
      debugPrint('[BackupService] Error restoring database: $e\n$stack');
      return (
        success: false,
        message: 'فشل استرجاع قاعدة البيانات: $e',
      );
    }
  }

  /// Path to the dedicated automatic backup folder ("ميزانيتي") on Android
  static const String androidDedicatedBackupPath = '/storage/emulated/0/Documents/ميزانيتي';

  /// Requests necessary storage permissions on Android.
  /// Requests Permission.manageExternalStorage (crucial for Android 11+ Scoped Storage)
  /// and Permission.storage (for Android 10 and below).
  Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // 1. Android 11+ (API 30+) Scoped Storage requirement
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
        debugPrint('[BackupService] Permission.manageExternalStorage requested: $manageStatus');
      }

      // 2. Android 10 and below storage requirement
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
        debugPrint('[BackupService] Permission.storage requested: $storageStatus');
      }

      final isGranted = manageStatus.isGranted || storageStatus.isGranted;
      debugPrint('[BackupService] Storage permission granted: $isGranted (manage: $manageStatus, storage: $storageStatus)');
      return isGranted;
    } catch (e, stack) {
      debugPrint('[BackupService] Error requesting storage permissions: $e\n$stack');
      return false;
    }
  }

  /// Resolves and ensures the dedicated auto-backup directory exists.
  /// - Android: /storage/emulated/0/Documents/ميزانيتي
  /// - iOS / fallback: getApplicationDocumentsDirectory() + /ميزانيتي
  Future<Directory> getDedicatedAutoBackupDirectory() async {
    Directory targetDir;
    if (Platform.isAndroid) {
      targetDir = Directory(androidDedicatedBackupPath);
      if (!targetDir.existsSync()) {
        try {
          targetDir.createSync(recursive: true);
          debugPrint('[BackupService] Created Android dedicated directory: ${targetDir.path}');
        } catch (e) {
          debugPrint('[BackupService] Direct creation of $androidDedicatedBackupPath failed: $e, falling back to app documents directory.');
          final baseDir = await getApplicationDocumentsDirectory();
          targetDir = Directory(join(baseDir.path, 'ميزانيتي'));
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
            debugPrint('[BackupService] Created fallback directory: ${targetDir.path}');
          }
        }
      }
    } else {
      // iOS / other platforms fallback
      final baseDir = await getApplicationDocumentsDirectory();
      targetDir = Directory(join(baseDir.path, 'ميزانيتي'));
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
        debugPrint('[BackupService] Created iOS/fallback directory: ${targetDir.path}');
      }
    }
    return targetDir;
  }

  /// Automatically creates a daily .db backup in the dedicated "ميزانيتي" folder
  Future<bool> checkAndRunDailyBackup() async {
    try {
      final isEnabled = await isAutoBackupEnabled();
      if (!isEnabled) {
        debugPrint('[BackupService] Daily auto-backup is disabled in settings.');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastAutoDate = prefs.getString(keyLastAutoBackupDate);

      if (lastAutoDate != todayStr) {
        // Request storage permissions before writing to public storage
        await requestStoragePermissions();

        final dbPath = await _dbHelper.getDatabaseFilePath();
        final dbFile = File(dbPath);
        if (!await dbFile.exists() || await dbFile.length() == 0) {
          debugPrint('[BackupService] FAILED: SQLite database file not found or empty at: $dbPath');
          return false;
        }

        final targetDir = await getDedicatedAutoBackupDirectory();
        final targetFileName = 'backup_$todayStr.db';
        final targetFile = File(join(targetDir.path, targetFileName));

        await dbFile.copy(targetFile.path);

        await prefs.setString(keyLastAutoBackupDate, todayStr);
        await prefs.setString(keyLastBackupDate, todayStr);

        debugPrint('[BackupService] SUCCESS: Daily auto-backup created in dedicated folder: ${targetFile.path}');
        return true;
      } else {
        debugPrint('[BackupService] Daily auto-backup already completed today ($todayStr).');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[BackupService] ERROR in daily auto-backup: $e\n$stack');
      return false;
    }
  }

  /// Manually creates a daily auto-backup file in the dedicated folder
  Future<({bool success, String message, String? savedPath})> createDedicatedBackupNow() async {
    try {
      await requestStoragePermissions();

      final dbPath = await _dbHelper.getDatabaseFilePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists() || await dbFile.length() == 0) {
        debugPrint('[BackupService] FAILED: Database file not found or empty at: $dbPath');
        return (
          success: false,
          message: 'ملف قاعدة البيانات غير موجود أو فارغ',
          savedPath: null,
        );
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final targetDir = await getDedicatedAutoBackupDirectory();
      final targetFileName = 'backup_$todayStr.db';
      final targetFile = File(join(targetDir.path, targetFileName));

      await dbFile.copy(targetFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyLastAutoBackupDate, todayStr);
      await prefs.setString(keyLastBackupDate, todayStr);

      debugPrint('[BackupService] SUCCESS: Dedicated backup created manually at: ${targetFile.path}');
      return (
        success: true,
        message: 'تم حفظ النسخة التلقائية بنجاح في مجلد ميزانيتي:\n${targetFile.path}',
        savedPath: targetFile.path,
      );
    } catch (e, stack) {
      debugPrint('[BackupService] ERROR creating dedicated backup: $e\n$stack');
      return (
        success: false,
        message: 'تعذر إنشاء النسخة في المجلد المخصص: $e',
        savedPath: null,
      );
    }
  }

  /// Returns the formatted date of the last successful backup
  Future<String?> getLastBackupDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyLastBackupDate);
    } catch (_) {
      return null;
    }
  }

  /// Returns whether daily auto-backup is enabled (default: true)
  Future<bool> isAutoBackupEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyAutoBackupEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Toggles daily auto-backup setting
  Future<void> setAutoBackupEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyAutoBackupEnabled, enabled);
    } catch (e) {
      debugPrint('[BackupService] Error setting auto-backup enabled: $e');
    }
  }

  Future<void> _recordBackupSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      await prefs.setString(keyLastBackupDate, todayStr);
    } catch (_) {}
  }
}
