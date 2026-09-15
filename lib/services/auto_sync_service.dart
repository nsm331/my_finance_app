import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'cloud_sync_service.dart';

/// Service responsible for automatically synchronizing local financial data
/// with Firebase Firestore whenever an active internet connection is detected.
class AutoSyncService {
  static const String keyAutoSyncEnabled = 'auto_cloud_sync_enabled';

  static final AutoSyncService instance = AutoSyncService._init();

  Connectivity _connectivity = Connectivity();
  CloudSyncService _cloudSyncService = CloudSyncService();
  AuthService _authService = AuthService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isAutoSyncing = false;
  DateTime? _lastSyncAttempt;

  /// Notifier reflecting whether an automatic synchronization is currently in progress
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  AutoSyncService._init();

  /// Check whether automatic sync on internet connection is enabled
  Future<bool> isAutoSyncEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyAutoSyncEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Enable or disable automatic synchronization upon internet connection
  Future<void> setAutoSyncEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyAutoSyncEnabled, enabled);
    } catch (_) {}
  }

  /// Initializes the connectivity listener to automatically synchronize data
  void initialize({
    Connectivity? connectivity,
    CloudSyncService? cloudSyncService,
    AuthService? authService,
  }) {
    if (connectivity != null) _connectivity = connectivity;
    if (cloudSyncService != null) _cloudSyncService = cloudSyncService;
    if (authService != null) _authService = authService;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // Check connectivity on startup and sync if online
    checkConnectivityAndSync();
  }

  /// Handle network changes detected by Connectivity
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isConnected = results.any((r) => r != ConnectivityResult.none);
    if (isConnected) {
      debugPrint('[AutoSyncService] Internet connection restored ($results). Triggering auto-sync...');
      syncNow(reason: 'internet_connected');
    } else {
      debugPrint('[AutoSyncService] Device is offline ($results).');
    }
  }

  /// Checks the current connectivity state and triggers sync if online
  Future<bool> checkConnectivityAndSync() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        return await syncNow(reason: 'startup_online');
      }
    } catch (e) {
      debugPrint('[AutoSyncService] checkConnectivityAndSync error: $e');
    }
    return false;
  }

  /// Executes an immediate synchronization push if conditions are met
  Future<bool> syncNow({String reason = 'manual'}) async {
    final enabled = await isAutoSyncEnabled();
    if (!enabled) {
      debugPrint('[AutoSyncService] Auto-sync skipped (disabled by user).');
      return false;
    }

    if (_isAutoSyncing) {
      debugPrint('[AutoSyncService] Auto-sync skipped (already in progress).');
      return false;
    }

    // Debounce/throttle rapid reconnections (e.g. WiFi flicker)
    if (reason != 'manual' && _lastSyncAttempt != null) {
      final diff = DateTime.now().difference(_lastSyncAttempt!);
      if (diff < const Duration(seconds: 20)) {
        debugPrint('[AutoSyncService] Auto-sync throttled (last sync attempt was ${diff.inSeconds}s ago).');
        return false;
      }
    }

    final userId = _authService.currentUserId ?? await AuthService.getCachedUserId();
    if (userId == null || userId.isEmpty) {
      debugPrint('[AutoSyncService] Auto-sync skipped (no user authenticated).');
      return false;
    }

    try {
      _isAutoSyncing = true;
      isSyncingNotifier.value = true;
      _lastSyncAttempt = DateTime.now();

      debugPrint('[AutoSyncService] Starting auto-sync for user: $userId (Reason: $reason)...');
      final result = await _cloudSyncService.uploadLocalDataToCloud(userId);

      debugPrint('[AutoSyncService] Auto-sync finished: Success=${result.success}, Items=${result.totalUploaded}');
      return result.success;
    } catch (e, stack) {
      debugPrint('[AutoSyncService] Auto-sync error: $e\n$stack');
      return false;
    } finally {
      _isAutoSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Disposes resources when no longer needed
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
