import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../core/services/auth_service.dart';

/// SmartDrip Auth Provider (FULL SYSTEM)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // =========================
  // GETTERS
  // =========================
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  AuthProvider() {
    _init();
    _listenAuthChanges();
  }

  // =========================
  // INIT SESSION RESTORE
  // =========================
  Future<void> _init() async {
    await _authService.init();

    final firebaseUser = _authService.firebaseUser;

    if (firebaseUser != null) {
      _user = _mapUser(firebaseUser);
    }

    _isInitialized = true;
    notifyListeners();
  }

  // =========================
  // REALTIME AUTH SYNC
  // =========================
  void _listenAuthChanges() {
    _authService.authStateChanges.listen((User? firebaseUser) {
      if (firebaseUser == null) {
        _user = null;
      } else {
        _user = _mapUser(firebaseUser);
      }
      notifyListeners();
    });
  }

  // =========================
  // LOGIN
  // =========================
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // REGISTER
  // =========================
  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerWithEmailAndPassword(
        name,
        email,
        password,
      );
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // GOOGLE LOGIN
  // =========================
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithGoogle();
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // FORGOT PASSWORD
  // =========================
  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // LOGOUT
  // =========================
  Future<void> logout() async {
    _setLoading(true);

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(_cleanError(e));
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // ⭐ NEW: UPDATE PROFILE (EDIT PROFILE SUPPORT)
  // =========================
  Future<bool> updateProfile({required String name}) async {
    _setLoading(true);
    _clearError();

    try {
      final firebaseUser = _authService.firebaseUser;

      if (firebaseUser == null) {
        _setError("No user logged in");
        return false;
      }

      await firebaseUser.updateDisplayName(name);

      _user = _user?.copyWith(name: name);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // =========================
  // HELPERS
  // =========================
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String e) {
    _error = e;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  String _cleanError(Object e) {
    return e.toString().replaceAll("Exception:", "").trim();
  }

  UserModel _mapUser(User user) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? 'SmartDrip User',
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );
  }
}