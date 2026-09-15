import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class AuthService {
  static const String keyAuthUid = 'auth_user_id';
  static const String keyAuthEmail = 'auth_user_email';

  final FirebaseAuth? _customAuth;

  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  FirebaseAuth get _auth {
    if (_customAuth != null) return _customAuth;
    return FirebaseService.auth;
  }

  /// Returns current Firebase user if available
  User? get currentUser {
    try {
      if (!FirebaseService.isInitialized) return null;
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Current user ID (falls back to local cached ID in offline situations)
  String? get currentUserId => currentUser?.uid;

  /// Returns true if a user is currently logged in
  bool get isLoggedIn => currentUser != null;

  /// Sign In with Email and Password
  Future<({bool success, String? message, User? user})> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (!FirebaseService.isInitialized) {
        final initOk = await FirebaseService.initialize();
        if (!initOk) {
          return (
            success: false,
            message: 'خدمة Firebase غير مفعلة، يرجى التأكد من إضافة google-services.json',
            user: null,
          );
        }
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _saveUserLocally(user.uid, user.email ?? '');
        return (success: true, message: 'تم تسجيل الدخول بنجاح', user: user);
      }

      return (success: false, message: 'فشل استرجاع بيانات الحساب', user: null);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signIn FirebaseAuthException: ${e.code} - ${e.message}');
      return (success: false, message: _mapFirebaseError(e.code), user: null);
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      return (success: false, message: 'حدث خطأ أثناء تسجيل الدخول: $e', user: null);
    }
  }

  /// Sign Up with Email and Password
  Future<({bool success, String? message, User? user})> signUp({
    required String email,
    required String password,
  }) async {
    try {
      if (!FirebaseService.isInitialized) {
        final initOk = await FirebaseService.initialize();
        if (!initOk) {
          return (
            success: false,
            message: 'خدمة Firebase غير مفعلة، يرجى التأكد من إضافة google-services.json',
            user: null,
          );
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await _saveUserLocally(user.uid, user.email ?? '');
        return (success: true, message: 'تم إنشاء الحساب بنجاح', user: user);
      }

      return (success: false, message: 'فشل إنشاء الحساب', user: null);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signUp FirebaseAuthException: ${e.code} - ${e.message}');
      return (success: false, message: _mapFirebaseError(e.code), user: null);
    } catch (e) {
      debugPrint('[AuthService] signUp error: $e');
      return (success: false, message: 'حدث خطأ أثناء إنشاء الحساب: $e', user: null);
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      if (FirebaseService.isInitialized) {
        await _auth.signOut();
      }
      await _clearUserLocally();
      debugPrint('[AuthService] User signed out and local cache cleared.');
    } catch (e) {
      debugPrint('[AuthService] Error signing out: $e');
    }
  }

  /// Get cached User ID from local preferences
  static Future<String?> getCachedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyAuthUid);
    } catch (_) {
      return null;
    }
  }

  /// Get cached Email from local preferences
  static Future<String?> getCachedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyAuthEmail);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUserLocally(String uid, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAuthUid, uid);
      await prefs.setString(keyAuthEmail, email);
    } catch (e) {
      debugPrint('[AuthService] Error saving user locally: $e');
    }
  }

  Future<void> _clearUserLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAuthUid);
      await prefs.remove(keyAuthEmail);
    } catch (e) {
      debugPrint('[AuthService] Error clearing user locally: $e');
    }
  }

  /// Translate Firebase error codes to user-friendly Arabic text
  static String getArabicErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب مسجل بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل لحساب آخر';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، يرجى استخدام 6 أحرف على الأقل';
      case 'network-request-failed':
        return 'تعذر الاتصال بالشبكة، يرجى التحقق من اتصال الإنترنت';
      case 'too-many-requests':
        return 'تم حظر المحاولات مؤقتاً لكثرة الطلبات، يرجى الانتظار قليلاً';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ في المصادقة ($code)';
    }
  }

  String _mapFirebaseError(String code) => getArabicErrorMessage(code);
}
