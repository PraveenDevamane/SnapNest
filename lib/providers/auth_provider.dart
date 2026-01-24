import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _dbService;
  
  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  String? _error;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider(this._authService, this._dbService) {
    _init();
  }

  // Getters
  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  String? get userId => _currentUser?.uid;

  /// Initialize auth state listener
  void _init() {
    _authSubscription = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  /// Handle auth state changes
  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } else {
      // Fetch or create user profile
      var appUser = await _dbService.getUser(user.uid);
      
      if (appUser == null) {
        // Create new user profile
        appUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _dbService.saveUser(appUser);
      }
      
      _currentUser = appUser;
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading();
      await _authService.signInWithEmail(email, password);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading();
      await _authService.signUpWithEmail(email, password);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading();
      await _authService.signInWithGoogle();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return false;
    
    try {
      final updatedUser = _currentUser!.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      
      await _dbService.saveUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading() {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    _status = _currentUser != null 
        ? AuthStatus.authenticated 
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
