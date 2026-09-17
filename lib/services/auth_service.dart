import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

/// Result record returned from all AuthService operations.
typedef AuthResult = ({bool success, String? message, User? user});

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

  /// Current user ID (Firebase UID)
  String? get currentUserId => currentUser?.uid;

  /// Returns true if a user is currently logged in via Firebase
  bool get isLoggedIn => currentUser != null;

  // ─────────────────────────────────────────────────────────────────────────
  // Email / Password
  // ─────────────────────────────────────────────────────────────────────────

  /// Sign In with Email and Password
  Future<AuthResult> signIn({
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
      return (success: false, message: 'حدث خطأ أثناء تسجيل الدخول', user: null);
    }
  }

  /// Sign Up with Email and Password
  Future<AuthResult> signUp({
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
      return (success: false, message: 'حدث خطأ أثناء إنشاء الحساب', user: null);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Google Sign-In
  // ─────────────────────────────────────────────────────────────────────────

  /// Sign In with Google OAuth.
  /// Returns a result with [success], [message], and the Firebase [user].
  Future<AuthResult> signInWithGoogle() async {
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

      User? user;

      if (kIsWeb) {
        // Web flow: use Firebase's native popup provider
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        // Mobile flow: use GoogleSignIn package
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          return (
            success: false,
            message: 'تم إلغاء تسجيل الدخول عبر Google',
            user: null,
          );
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user != null) {
        await _saveUserLocally(user.uid, user.email ?? '');
        debugPrint('[AuthService] Google Sign-In success: ${user.email}');
        return (
          success: true,
          message: 'تم تسجيل الدخول بـ Google بنجاح',
          user: user,
        );
      }

      return (success: false, message: 'فشل استرجاع بيانات حساب Google', user: null);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signInWithGoogle FirebaseAuthException: ${e.code}');
      return (success: false, message: _mapFirebaseError(e.code), user: null);
    } catch (e) {
      debugPrint('[AuthService] signInWithGoogle error: $e');
      // Handle common non-Firebase errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('socket')) {
        return (
          success: false,
          message: 'تعذر الاتصال بالشبكة، يرجى التحقق من اتصال الإنترنت',
          user: null,
        );
      }
      return (
        success: false,
        message: 'حدث خطأ أثناء تسجيل الدخول عبر Google',
        user: null,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sign Out
  // ─────────────────────────────────────────────────────────────────────────

  /// Signs out from Firebase and optionally from Google Sign-In.
  Future<void> signOut() async {
    try {
      if (FirebaseService.isInitialized) {
        await _auth.signOut();
        // Also sign out from Google if on mobile and session was Google-based
        if (!kIsWeb) {
          try {
            final googleSignIn = GoogleSignIn();
            if (await googleSignIn.isSignedIn()) {
              await googleSignIn.signOut();
            }
          } catch (_) {
            // Google sign out failure is non-critical
          }
        }
      }
      await _clearUserLocally();
      debugPrint('[AuthService] User signed out and local cache cleared.');
    } catch (e) {
      debugPrint('[AuthService] Error signing out: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local Persistence Helpers
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // Error Mapping
  // ─────────────────────────────────────────────────────────────────────────

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
      case 'account-exists-with-different-credential':
        return 'يوجد حساب مسجل بهذا البريد بطريقة تسجيل دخول مختلفة';
      case 'google-sign-in-cancelled':
        return 'تم إلغاء تسجيل الدخول عبر Google';
      case 'popup-closed-by-user':
        return 'تم إغلاق نافذة تسجيل الدخول';
      case 'cancelled-popup-request':
        return 'تم إلغاء طلب تسجيل الدخول';
      case 'popup-blocked':
        return 'قام المتصفح بحظر نافذة تسجيل الدخول، يرجى السماح بالنوافذ المنبثقة (Popups)';
      case 'unauthorized-domain':
        return 'هذا النطاق غير مصرح به في إعدادات Firebase Authentication';
      case 'operation-not-allowed':
        return 'تسجيل الدخول عبر Google غير مفعّل في لوحة تحكم Firebase';
      default:
        return 'حدث خطأ في المصادقة ($code)';
    }
  }

  String _mapFirebaseError(String code) => getArabicErrorMessage(code);
}
