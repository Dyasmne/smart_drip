import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/user_model.dart';
import '../core/services/auth_service.dart';

/// SmartDrip Auth Provider (FULL SYSTEM)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  // Same Realtime Database already used for sensor/pump data elsewhere in
  // the app — no Firestore needed, so no separate billing/quota to worry
  // about.
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref('users');

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
      _user = await _mapUser(firebaseUser);
    }

    _isInitialized = true;
    notifyListeners();
  }

  // =========================
  // REALTIME AUTH SYNC
  // =========================
  void _listenAuthChanges() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
      } else {
        _user = await _mapUser(firebaseUser);
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
  // ⭐ UPDATE PROFILE (name / deviceId / photoUrl)
  // =========================
  //
  // `name` still updates Firebase Auth's displayName directly (as before).
  // `deviceId` and `photoUrl` aren't part of FirebaseAuth's User object, so
  // they're persisted to `users/{uid}` in the Realtime Database instead —
  // otherwise they'd only live in memory and get wiped out the next time
  // `_mapUser` runs (login, token refresh, app restart, etc).
  //
  // Pass only the fields you want to change; omitted ones are left as-is.
  Future<bool> updateProfile({
    String? name,
    String? deviceId,
    String? photoUrl,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final firebaseUser = _authService.firebaseUser;

      if (firebaseUser == null) {
        _setError("No user logged in");
        return false;
      }

      if (name != null && name.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(name.trim());
      }

      _user = _user?.copyWith(
        name: name,
        deviceId: deviceId,
        photoUrl: photoUrl,
      );

      if (_user != null) {
        await _usersRef.child(firebaseUser.uid).update(_user!.toFirebase());
      }

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

  /// Builds the app's UserModel from the FirebaseAuth user, then layers in
  /// whatever's saved at `users/{uid}` in the Realtime Database (deviceId,
  /// photoUrl, role, original createdAt) — since those fields don't exist
  /// on FirebaseAuth's User object at all. If no RTDB node exists yet
  /// (first sign-in), one is created so future updateProfile() calls have
  /// something to merge into.
  Future<UserModel> _mapUser(User firebaseUser) async {
    UserModel base = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'SmartDrip User',
      email: firebaseUser.email ?? '',
      createdAt: DateTime.now(),
    );

    try {
      final snapshot = await _usersRef.child(firebaseUser.uid).get();
      final data = snapshot.value;

      if (data != null && data is Map) {
        final saved = UserModel.fromJson(Map<String, dynamic>.from(data));

        base = base.copyWith(
          deviceId: saved.deviceId,
          photoUrl: saved.photoUrl,
          role: saved.role,
          createdAt: saved.createdAt,
        );
      } else {
        await _usersRef.child(firebaseUser.uid).update(base.toFirebase());
      }
    } catch (e) {
      debugPrint("Failed to load user profile from Realtime Database: $e");
    }

    return base;
  }
}