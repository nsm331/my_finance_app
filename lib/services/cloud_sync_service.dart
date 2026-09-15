import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'database_helper.dart';
import 'firebase_service.dart';

class CloudSyncService {
  static const String keyLastCloudSyncDate = 'last_cloud_sync_date';
  static const int _batchChunkSize = 400; // Under Firestore 500-op limit

  final DatabaseHelper _dbHelper;
  final AuthService _authService;
  final FirebaseFirestore? _customFirestore;

  CloudSyncService({
    DatabaseHelper? dbHelper,
    AuthService? authService,
    FirebaseFirestore? firestore,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _authService = authService ?? AuthService(),
        _customFirestore = firestore;

  FirebaseFirestore get _firestore {
    if (_customFirestore != null) return _customFirestore;
    return FirebaseService.firestore;
  }

  /// Uploads all local SQLite data for the current user to Firestore (Push)
  Future<({bool success, String message, int totalUploaded})> uploadLocalDataToCloud([String? targetUserId]) async {
    try {
      if (!FirebaseService.isInitialized) {
        final initOk = await FirebaseService.initialize();
        if (!initOk) {
          return (
            success: false,
            message: 'خدمة Firebase غير مفعلة، يرجى إضافة ملف google-services.json',
            totalUploaded: 0,
          );
        }
      }

      final userId = targetUserId ?? _authService.currentUserId;
      if (userId == null || userId.isEmpty) {
        return (
          success: false,
          message: 'يجب تسجيل الدخول أولاً لإتمام المزامنة السحابية',
          totalUploaded: 0,
        );
      }

      final userDocRef = _firestore.collection('users').doc(userId);

      // 1. Fetch raw data from local SQLite
      final wallets = await _dbHelper.getRawTableRows(DatabaseHelper.tableWallets, userId: userId);
      final transactions = await _dbHelper.getRawTableRows(DatabaseHelper.tableTransactions, userId: userId);
      final persons = await _dbHelper.getRawTableRows(DatabaseHelper.tablePersons, userId: userId);
      final debts = await _dbHelper.getRawTableRows(DatabaseHelper.tableDebts, userId: userId);
      final categories = await _dbHelper.getRawTableRows(DatabaseHelper.tableCategories, userId: userId);
      final recurring = await _dbHelper.getRawTableRows(DatabaseHelper.tableRecurring, userId: userId);

      int totalCount = wallets.length + transactions.length + persons.length + debts.length + categories.length + recurring.length;

      // 2. Prepare items to upload
      final List<({DocumentReference docRef, Map<String, dynamic> data})> operations = [];

      for (final w in wallets) {
        final id = w['id'].toString();
        operations.add((docRef: userDocRef.collection('wallets').doc(id), data: w));
      }

      for (final t in transactions) {
        final id = t['id'].toString();
        operations.add((docRef: userDocRef.collection('transactions').doc(id), data: t));
      }

      for (final p in persons) {
        final id = p['id'].toString();
        operations.add((docRef: userDocRef.collection('persons').doc(id), data: p));
      }

      for (final d in debts) {
        final id = d['id'].toString();
        operations.add((docRef: userDocRef.collection('debts').doc(id), data: d));
      }

      for (final c in categories) {
        final id = c['id'].toString();
        operations.add((docRef: userDocRef.collection('categories').doc(id), data: c));
      }

      for (final r in recurring) {
        final id = r['id'].toString();
        operations.add((docRef: userDocRef.collection('recurring').doc(id), data: r));
      }

      // 3. Commit in chunks using WriteBatch
      for (int i = 0; i < operations.length; i += _batchChunkSize) {
        final batch = _firestore.batch();
        final end = (i + _batchChunkSize < operations.length) ? i + _batchChunkSize : operations.length;
        final chunk = operations.sublist(i, end);

        for (final op in chunk) {
          final dataWithMeta = Map<String, dynamic>.from(op.data);
          dataWithMeta['_synced_at'] = FieldValue.serverTimestamp();
          batch.set(op.docRef, dataWithMeta, SetOptions(merge: true));
        }

        await batch.commit();
      }

      // Update user root doc metadata
      await userDocRef.set({
        'last_sync_at': FieldValue.serverTimestamp(),
        'email': _authService.currentUser?.email ?? '',
        'records_count': totalCount,
      }, SetOptions(merge: true));

      await _recordSyncSuccess();

      debugPrint('[CloudSyncService] Upload completed: $totalCount items uploaded.');
      return (
        success: true,
        message: 'تم رفع $totalCount سجلاً إلى سحابة Firebase بنجاح!',
        totalUploaded: totalCount,
      );
    } catch (e, stack) {
      debugPrint('[CloudSyncService] Error in uploadLocalDataToCloud: $e\n$stack');
      return (
        success: false,
        message: 'فشل رفع البيانات إلى السحابة: $e',
        totalUploaded: 0,
      );
    }
  }

  /// Downloads all cloud data for the current user from Firestore into SQLite (Pull)
  Future<({bool success, String message, int totalDownloaded})> downloadCloudDataToLocal([String? targetUserId]) async {
    try {
      if (!FirebaseService.isInitialized) {
        final initOk = await FirebaseService.initialize();
        if (!initOk) {
          return (
            success: false,
            message: 'خدمة Firebase غير مفعلة، يرجى إضافة ملف google-services.json',
            totalDownloaded: 0,
          );
        }
      }

      final userId = targetUserId ?? _authService.currentUserId;
      if (userId == null || userId.isEmpty) {
        return (
          success: false,
          message: 'يجب تسجيل الدخول أولاً لاستعادة البيانات من السحابة',
          totalDownloaded: 0,
        );
      }

      final userDocRef = _firestore.collection('users').doc(userId);

      // Fetch all subcollections in parallel
      final results = await Future.wait([
        userDocRef.collection('wallets').get(),
        userDocRef.collection('transactions').get(),
        userDocRef.collection('persons').get(),
        userDocRef.collection('debts').get(),
        userDocRef.collection('categories').get(),
        userDocRef.collection('recurring').get(),
      ]);

      final walletsDocs = results[0].docs;
      final txDocs = results[1].docs;
      final personsDocs = results[2].docs;
      final debtsDocs = results[3].docs;
      final categoriesDocs = results[4].docs;
      final recurringDocs = results[5].docs;

      int totalCount = walletsDocs.length +
          txDocs.length +
          personsDocs.length +
          debtsDocs.length +
          categoriesDocs.length +
          recurringDocs.length;

      if (totalCount == 0) {
        return (
          success: true,
          message: 'لا توجد بيانات محفوظة في السحابة لهذا الحساب بعد.',
          totalDownloaded: 0,
        );
      }

      // Convert docs into SQLite map rows (stripping Firestore-specific metadata)
      List<Map<String, dynamic>> cleanRows(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
        return docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data.remove('_synced_at');
          return data;
        }).toList();
      }

      // Atomically replace local SQLite tables
      if (walletsDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableWallets, cleanRows(walletsDocs), userId: userId);
      }
      if (personsDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tablePersons, cleanRows(personsDocs), userId: userId);
      }
      if (categoriesDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableCategories, cleanRows(categoriesDocs), userId: userId);
      }
      if (txDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableTransactions, cleanRows(txDocs), userId: userId);
      }
      if (debtsDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableDebts, cleanRows(debtsDocs), userId: userId);
      }
      if (recurringDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableRecurring, cleanRows(recurringDocs), userId: userId);
      }

      await _recordSyncSuccess();

      debugPrint('[CloudSyncService] Download completed: $totalCount items restored.');
      return (
        success: true,
        message: 'تمت استعادة $totalCount سجلاً من السحابة بنجاح!',
        totalDownloaded: totalCount,
      );
    } catch (e, stack) {
      debugPrint('[CloudSyncService] Error in downloadCloudDataToLocal: $e\n$stack');
      return (
        success: false,
        message: 'فشل استرجاع البيانات من السحابة: $e',
        totalDownloaded: 0,
      );
    }
  }

  /// Returns the formatted timestamp of the last cloud sync
  Future<String?> getLastSyncDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyLastCloudSyncDate);
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordSyncSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      await prefs.setString(keyLastCloudSyncDate, nowStr);
    } catch (_) {}
  }
}
