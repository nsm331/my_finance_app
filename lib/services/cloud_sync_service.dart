import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'database_helper.dart';
import 'firebase_service.dart';
import '../models/transaction_model.dart';
import '../models/app_currency.dart';

class CloudSyncService {
  static const String keyLastCloudSyncDate = 'last_cloud_sync_date';
  static const int _batchChunkSize = 400; // Under Firestore 500-op limit

  final DatabaseHelper _dbHelper;
  final AuthService _authService;
  final FirebaseFirestore? _customFirestore;

  static CloudSyncService? _instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _transactionsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _walletsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _debtsSubscription;

  factory CloudSyncService({
    DatabaseHelper? dbHelper,
    AuthService? authService,
    FirebaseFirestore? firestore,
  }) {
    if (dbHelper != null || authService != null || firestore != null) {
      return CloudSyncService._custom(
        dbHelper: dbHelper,
        authService: authService,
        firestore: firestore,
      );
    }
    _instance ??= CloudSyncService._internal();
    return _instance!;
  }

  CloudSyncService._internal()
      : _dbHelper = DatabaseHelper.instance,
        _authService = AuthService(),
        _customFirestore = null;

  CloudSyncService._custom({
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

        await batch.commit().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('انتهت مهلة إرسال البيانات إلى خادم Firestore'),
        );
      }

      // Update user root doc metadata
      await userDocRef.set({
        'last_sync_at': FieldValue.serverTimestamp(),
        'email': _authService.currentUser?.email ?? '',
        'records_count': totalCount,
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('انتهت مهلة تحديث معلومات المزامنة السحابية'),
      );

      await _recordSyncSuccess();

      debugPrint('[CloudSyncService] Upload completed: $totalCount items uploaded.');
      return (
        success: true,
        message: 'تم رفع $totalCount سجلاً إلى سحابة Firebase بنجاح!',
        totalUploaded: totalCount,
      );
    } on FirebaseException catch (fe, stack) {
      debugPrint('[CloudSyncService] FirebaseException in uploadLocalDataToCloud: ${fe.code} - ${fe.message}\n$stack');
      String msg;
      if (fe.code == 'permission-denied') {
        msg = 'تم رفض الإذن من السحابة. يرجى التأكد من ضبط قواعد الأمان (Firestore Rules) في لوحة تحكم Firebase.';
      } else if (fe.code == 'not-found' || fe.message?.contains('database') == true) {
        msg = 'قاعدة بيانات Cloud Firestore غير مفعلة، يرجى تفعيلها بالضغط على Create Database في لوحة Firebase.';
      } else if (fe.code == 'unavailable') {
        msg = 'خوادم Firestore غير متاحة حالياً أو الاتصال ضعيف، يرجى التحقق من اتصال الإنترنت.';
      } else {
        msg = 'خطأ سحابي (${fe.code}): ${fe.message ?? "تعذر إتمام المزامنة"}';
      }
      return (
        success: false,
        message: msg,
        totalUploaded: 0,
      );
    } on TimeoutException catch (te) {
      debugPrint('[CloudSyncService] Timeout in uploadLocalDataToCloud: $te');
      return (
        success: false,
        message: 'انتهت مهلة الاتصال بسحابة Firebase (15 ثانية). يرجى التأكد من إنشاء قاعدة بيانات Firestore في لوحة تحكم Firebase وضبط قواعد الأمان.',
        totalUploaded: 0,
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

      // Fetch all subcollections in parallel with timeout
      final results = await Future.wait([
        userDocRef.collection('wallets').get().timeout(const Duration(seconds: 12)),
        userDocRef.collection('transactions').get().timeout(const Duration(seconds: 12)),
        userDocRef.collection('persons').get().timeout(const Duration(seconds: 12)),
        userDocRef.collection('debts').get().timeout(const Duration(seconds: 12)),
        userDocRef.collection('categories').get().timeout(const Duration(seconds: 12)),
        userDocRef.collection('recurring').get().timeout(const Duration(seconds: 12)),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('انتهت مهلة استرجاع البيانات من السحابة'),
      );

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
      List<Map<String, dynamic>> cleanRows(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {bool isWallets = false}) {
        return docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data.remove('_synced_at');
          if (isWallets && data['id'] is String) {
            data['id'] = int.tryParse(data['id'].toString()) ?? data['id'];
          }
          return data;
        }).toList();
      }

      // Atomically replace local SQLite tables
      if (walletsDocs.isNotEmpty) {
        await _dbHelper.replaceUserData(DatabaseHelper.tableWallets, cleanRows(walletsDocs, isWallets: true), userId: userId);
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
    } on FirebaseException catch (fe, stack) {
      debugPrint('[CloudSyncService] FirebaseException in downloadCloudDataToLocal: ${fe.code} - ${fe.message}\n$stack');
      String msg;
      if (fe.code == 'permission-denied') {
        msg = 'تم رفض الإذن من السحابة. يرجى التأكد من ضبط قواعد الأمان (Rules) في لوحة تحكم Firebase.';
      } else if (fe.code == 'not-found' || fe.message?.contains('database') == true) {
        msg = 'قاعدة بيانات Firestore غير مفعلة في مشروع Firebase، يرجى تفعيلها من لوحة Firebase.';
      } else if (fe.code == 'unavailable') {
        msg = 'خوادم Firestore غير متاحة حالياً أو الاتصال ضعيف، يرجى التحقق من اتصال الإنترنت.';
      } else {
        msg = 'خطأ سحابي (${fe.code}): ${fe.message ?? "تعذر استرجاع البيانات"}';
      }
      return (
        success: false,
        message: msg,
        totalDownloaded: 0,
      );
    } on TimeoutException catch (te) {
      debugPrint('[CloudSyncService] Timeout in downloadCloudDataToLocal: $te');
      return (
        success: false,
        message: 'انتهت مهلة استرجاع البيانات من السحابة (15 ثانية). يرجى التحقق من اتصال الإنترنت وتفعيل Firestore.',
        totalDownloaded: 0,
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

  // ==========================================
  // REAL-TIME SYNC ENGINE
  // ==========================================

  // --- Transactions ---

  /// Pushes a single transaction write/update to Firestore in real-time.
  Future<void> pushTransaction(TransactionModel tx) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      final map = {
        'id': tx.id,
        'title': tx.title,
        'amount': tx.amount,
        'currency': tx.currency.code,
        'type': tx.type.name,
        'category_id': tx.categoryId,
        'category_name': tx.categoryName,
        'category_icon_code': tx.categoryIconCode,
        'category_color_value': tx.categoryColorValue,
        'date': tx.date.toIso8601String(),
        'notes': tx.notes,
        'created_at': tx.createdAt.toIso8601String(),
        'wallet_id': tx.walletId,
        'isTransfer': tx.isTransfer,
        'transfer_id': tx.transferId,
        'exchange_rate': tx.exchangeRate,
        'target_currency': tx.targetCurrency?.code,
        'target_amount': tx.targetAmount,
        'is_recurring': tx.isRecurring ? 1 : 0,
        'recurring_id': tx.recurringId,
        'user_id': uid,
        '_synced_at': FieldValue.serverTimestamp(),
      };

      _firestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(tx.id)
          .set(map, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('[CloudSyncService] Error pushing transaction ${tx.id}: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Push transaction exception: $e');
    }
  }

  /// Deletes a transaction from Firestore in real-time.
  Future<void> deleteTransactionFromCloud(String id) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      _firestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc(id)
          .delete()
          .catchError((e) {
        debugPrint('[CloudSyncService] Error deleting transaction $id from cloud: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Delete transaction exception: $e');
    }
  }

  // --- Wallets ---

  /// Pushes a single wallet to Firestore under users/{uid}/wallets/{walletId}
  Future<void> pushWallet(Map<String, dynamic> walletMap) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      final id = walletMap['id']?.toString();
      if (id == null || id.isEmpty) return;

      final data = Map<String, dynamic>.from(walletMap);
      data['user_id'] = uid;
      data['_synced_at'] = FieldValue.serverTimestamp();

      _firestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc(id)
          .set(data, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('[CloudSyncService] Error pushing wallet $id: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Push wallet exception: $e');
    }
  }

  /// Deletes a wallet from Firestore under users/{uid}/wallets/{walletId}
  Future<void> deleteWalletFromCloud(String walletId) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      _firestore
          .collection('users')
          .doc(uid)
          .collection('wallets')
          .doc(walletId)
          .delete()
          .catchError((e) {
        debugPrint('[CloudSyncService] Error deleting wallet $walletId: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Delete wallet exception: $e');
    }
  }

  // --- Categories ---

  /// Pushes a single category to Firestore under users/{uid}/categories/{categoryId}
  Future<void> pushCategory(Map<String, dynamic> categoryMap) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      final id = categoryMap['id']?.toString();
      if (id == null || id.isEmpty) return;

      final data = Map<String, dynamic>.from(categoryMap);
      data['user_id'] = uid;
      data['_synced_at'] = FieldValue.serverTimestamp();

      _firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(id)
          .set(data, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('[CloudSyncService] Error pushing category $id: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Push category exception: $e');
    }
  }

  /// Deletes a category from Firestore under users/{uid}/categories/{categoryId}
  Future<void> deleteCategoryFromCloud(String categoryId) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      _firestore
          .collection('users')
          .doc(uid)
          .collection('categories')
          .doc(categoryId)
          .delete()
          .catchError((e) {
        debugPrint('[CloudSyncService] Error deleting category $categoryId: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Delete category exception: $e');
    }
  }

  // --- Debts ---

  /// Pushes a single debt to Firestore under users/{uid}/debts/{debtId}
  Future<void> pushDebt(Map<String, dynamic> debtMap) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      final id = debtMap['id']?.toString();
      if (id == null || id.isEmpty) return;

      final data = Map<String, dynamic>.from(debtMap);
      data['user_id'] = uid;
      data['_synced_at'] = FieldValue.serverTimestamp();

      _firestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc(id)
          .set(data, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('[CloudSyncService] Error pushing debt $id: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Push debt exception: $e');
    }
  }

  /// Deletes a debt from Firestore under users/{uid}/debts/{debtId}
  Future<void> deleteDebtFromCloud(String debtId) async {
    try {
      final uid = _authService.currentUserId;
      if (uid == null || uid.isEmpty) return;

      _firestore
          .collection('users')
          .doc(uid)
          .collection('debts')
          .doc(debtId)
          .delete()
          .catchError((e) {
        debugPrint('[CloudSyncService] Error deleting debt $debtId: $e');
      });
    } catch (e) {
      debugPrint('[CloudSyncService] Delete debt exception: $e');
    }
  }

  // --- Real-time Listeners ---

  void _setupCollectionListener({
    required String collectionName,
    required String tableName,
    required String uid,
    required VoidCallback? onDataChanged,
    required void Function(StreamSubscription<QuerySnapshot<Map<String, dynamic>>> sub) onSubCreated,
  }) {
    final sub = _firestore
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) async {
      bool localModified = false;

      for (final change in snapshot.docChanges) {
        // Echo-loop prevention: Ignore locally initiated optimistic writes still pending write
        if (change.doc.metadata.hasPendingWrites) {
          continue;
        }

        final data = change.doc.data();
        final docId = change.doc.id;

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          if (data != null) {
            try {
              final row = Map<String, dynamic>.from(data);
              row.remove('_synced_at');
              row['user_id'] = uid;
              if (tableName == DatabaseHelper.tableWallets && row['id'] is String) {
                row['id'] = int.tryParse(row['id'].toString()) ?? row['id'];
              }
              await _dbHelper.upsertRawRow(tableName, row);
              localModified = true;
            } catch (e) {
              debugPrint('[CloudSyncService] Error saving remote $collectionName doc $docId to SQLite: $e');
            }
          }
        } else if (change.type == DocumentChangeType.removed) {
          try {
            await _dbHelper.deleteRawRow(tableName, 'id = ?', [docId]);
            localModified = true;
          } catch (e) {
            debugPrint('[CloudSyncService] Error deleting remote $collectionName doc $docId from SQLite: $e');
          }
        }
      }

      if (localModified) {
        debugPrint('[CloudSyncService] Remote $collectionName synced to SQLite. Refreshing state.');
        await _recordSyncSuccess();
        onDataChanged?.call();
      }
    }, onError: (err) {
      debugPrint('[CloudSyncService] Real-time listener error for $collectionName: $err');
    });

    onSubCreated(sub);
  }

  /// Starts real-time listeners on Firestore collections (transactions, wallets, categories, debts).
  /// Automatically prevents echo-loops by verifying hasPendingWrites.
  void startRealTimeListeners({VoidCallback? onDataChanged}) {
    final uid = _authService.currentUserId;
    if (uid == null || uid.isEmpty) {
      debugPrint('[CloudSyncService] startRealTimeListeners skipped: No authenticated user.');
      return;
    }

    if (_transactionsSubscription != null ||
        _walletsSubscription != null ||
        _categoriesSubscription != null ||
        _debtsSubscription != null) {
      debugPrint('[CloudSyncService] Real-time listeners already active for user: $uid');
      return;
    }

    debugPrint('[CloudSyncService] Starting all real-time Firestore listeners for user: $uid');

    // 1. Transactions
    _setupCollectionListener(
      collectionName: 'transactions',
      tableName: DatabaseHelper.tableTransactions,
      uid: uid,
      onDataChanged: onDataChanged,
      onSubCreated: (s) => _transactionsSubscription = s,
    );

    // 2. Wallets
    _setupCollectionListener(
      collectionName: 'wallets',
      tableName: DatabaseHelper.tableWallets,
      uid: uid,
      onDataChanged: onDataChanged,
      onSubCreated: (s) => _walletsSubscription = s,
    );

    // 3. Categories
    _setupCollectionListener(
      collectionName: 'categories',
      tableName: DatabaseHelper.tableCategories,
      uid: uid,
      onDataChanged: onDataChanged,
      onSubCreated: (s) => _categoriesSubscription = s,
    );

    // 4. Debts
    _setupCollectionListener(
      collectionName: 'debts',
      tableName: DatabaseHelper.tableDebts,
      uid: uid,
      onDataChanged: onDataChanged,
      onSubCreated: (s) => _debtsSubscription = s,
    );
  }

  /// Stops all real-time listeners and frees resources
  void stopRealTimeListeners() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = null;
    _walletsSubscription?.cancel();
    _walletsSubscription = null;
    _categoriesSubscription?.cancel();
    _categoriesSubscription = null;
    _debtsSubscription?.cancel();
    _debtsSubscription = null;
    debugPrint('[CloudSyncService] All real-time listeners successfully stopped.');
  }
}
