import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Central service for managing Firebase lifecycle, Authentication, and Firestore sync.
class FirebaseService {
  static bool _isInitialized = false;

  /// Returns true if Firebase has been successfully initialized
  static bool get isInitialized => _isInitialized;

  /// Returns the current Firebase User, or null if not authenticated or not initialized
  static User? get currentUser {
    if (!_isInitialized) return null;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a user is currently signed in
  static bool get isUserSignedIn => currentUser != null;

  /// Safely initializes Firebase.
  /// If google-services.json is not yet present, catches gracefully and keeps app functional offline.
  static Future<bool> initialize() async {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyCj8PgDljhozoBbbwjQ7eG3lWKG7J7iqQU",
            appId: "1:382217614763:web:497cc52d928955cd5eceee",
            messagingSenderId: "382217614763",
            projectId: "my-finance-app-2d3f7",
            authDomain: "my-finance-app-2d3f7.firebaseapp.com",
            storageBucket: "my-finance-app-2d3f7.firebasestorage.app",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase successfully initialized.');
      return true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('[FirebaseService] Firebase initialization skipped or failed: $e');
      return false;
    }
  }

  /// FirebaseAuth instance (throws StateError if Firebase is not initialized)
  static FirebaseAuth get auth {
    if (!_isInitialized) {
      throw StateError('Firebase is not initialized. Please ensure google-services.json is added.');
    }
    return FirebaseAuth.instance;
  }

  /// FirebaseFirestore instance (throws StateError if Firebase is not initialized)
  static FirebaseFirestore get firestore {
    if (!_isInitialized) {
      throw StateError('Firebase is not initialized. Please ensure google-services.json is added.');
    }
    return FirebaseFirestore.instance;
  }
}
