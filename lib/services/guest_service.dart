import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages local-only Guest Mode state via SharedPreferences.
/// No Firebase, no network — 100% offline.
class GuestService {
  static const String _keyIsGuestMode = 'isGuestMode';

  /// The static local user ID used for all guest SQLite rows.
  static const String guestUserId = 'guest_user';

  /// Returns true if the app is currently running in Guest Mode.
  static Future<bool> isGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsGuestMode) ?? false;
    } catch (e) {
      debugPrint('[GuestService] isGuestMode error: $e');
      return false;
    }
  }

  /// Activates Guest Mode: sets the flag and the static user ID.
  static Future<void> enterGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsGuestMode, true);
      debugPrint('[GuestService] Guest mode ACTIVATED — userId: $guestUserId');
    } catch (e) {
      debugPrint('[GuestService] enterGuestMode error: $e');
    }
  }

  /// Deactivates Guest Mode: clears the flag so the normal auth flow resumes.
  static Future<void> exitGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsGuestMode);
      debugPrint('[GuestService] Guest mode CLEARED');
    } catch (e) {
      debugPrint('[GuestService] exitGuestMode error: $e');
    }
  }
}
