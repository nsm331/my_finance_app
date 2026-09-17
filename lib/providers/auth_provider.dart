import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/guest_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isLoading = false;
  bool _isGuestMode = false;
  String? _errorMessage;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  bool get isLoading => _isLoading;
  bool get isGuestMode => _isGuestMode;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _authService.currentUser;
  /// Returns the active user ID: 'guest_user' in guest mode, Firebase UID otherwise.
  String? get userId => _isGuestMode ? GuestService.guestUserId : _authService.currentUserId;
  String? get userEmail => currentUser?.email;
  bool get isAuthenticated => _authService.isLoggedIn;

  Future<void> _init() async {
    // Check if guest mode was previously enabled
    _isGuestMode = await GuestService.isGuestMode();
    if (_isGuestMode) {
      DatabaseHelper.instance.setActiveUserId(GuestService.guestUserId);
      notifyListeners();
      return;
    }
    // Set active Firebase user ID in DatabaseHelper
    if (userId != null) {
      DatabaseHelper.instance.setActiveUserId(userId);
    }
  }

  /// Sign In with Email & Password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signIn(email: email, password: password);
    _isLoading = false;

    if (result.success && result.user != null) {
      _errorMessage = null;
      DatabaseHelper.instance.setActiveUserId(result.user!.uid);
      // Link any existing offline records to this user
      await DatabaseHelper.instance.linkLocalDataToUser(result.user!.uid);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Sign Up with Email & Password
  Future<bool> signUp({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signUp(email: email, password: password);
    _isLoading = false;

    if (result.success && result.user != null) {
      _errorMessage = null;
      DatabaseHelper.instance.setActiveUserId(result.user!.uid);
      // Link any existing offline records to this user
      await DatabaseHelper.instance.linkLocalDataToUser(result.user!.uid);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Sign In with Google OAuth
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    _isLoading = false;

    if (result.success && result.user != null) {
      _errorMessage = null;
      _isGuestMode = false;
      DatabaseHelper.instance.setActiveUserId(result.user!.uid);
      await DatabaseHelper.instance.linkLocalDataToUser(result.user!.uid);
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    DatabaseHelper.instance.setActiveUserId(null);

    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Activates local-only Guest Mode (no Firebase interaction).
  Future<void> enterGuestMode() async {
    await GuestService.enterGuestMode();
    _isGuestMode = true;
    DatabaseHelper.instance.setActiveUserId(GuestService.guestUserId);
    notifyListeners();
  }

  /// Exits Guest Mode, clears the flag, and resets the active user.
  Future<void> exitGuestMode() async {
    await GuestService.exitGuestMode();
    _isGuestMode = false;
    DatabaseHelper.instance.setActiveUserId(null);
    notifyListeners();
  }
}
