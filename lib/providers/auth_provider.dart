import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/user_model.dart';
import '../core/services/auth_service.dart';
import '../core/services/fcm_service.dart';

/// SmartDrip Auth Provider
///
/// Handles:
/// - Login
/// - Registration
/// - Google sign-in
/// - Logout
/// - Forgot password
/// - User profile
/// - Activity logs
/// - FCM token registration per user
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // Realtime Database references
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref('users');

  final DatabaseReference _activityLogsRef =
      FirebaseDatabase.instance.ref('smartdrip/activity_logs');

  UserModel? _user;

  bool _isLoading = false;
  bool _isInitialized = false;

  String? _error;

  // ============================================================
  // GETTERS
  // ============================================================

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  bool get isAuthenticated => _user != null;

  bool get isInitialized => _isInitialized;

  String? get error => _error;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  AuthProvider() {
    _init();
    _listenAuthChanges();
  }

  // ============================================================
  // INITIALIZE SESSION
  // ============================================================

  Future<void> _init() async {
    await _authService.init();

    final firebaseUser = _authService.firebaseUser;

    if (firebaseUser != null) {
      _user = await _mapUser(firebaseUser);

      // Register FCM token for the currently logged-in user.
      await _registerFcmToken();
    }

    _isInitialized = true;

    notifyListeners();
  }

  // ============================================================
  // AUTH STATE CHANGES
  // ============================================================

  void _listenAuthChanges() {
    _authService.authStateChanges.listen(
      (User? firebaseUser) async {
        if (firebaseUser == null) {
          _user = null;
        } else {
          _user = await _mapUser(firebaseUser);

          // Register FCM token whenever a user is logged in.
          await _registerFcmToken();
        }

        notifyListeners();
      },
    );
  }

  // ============================================================
  // REGISTER FCM TOKEN
  // ============================================================

  Future<void> _registerFcmToken() async {
    try {
      await FcmService.init();
      await FcmService.registerCurrentUser();

      debugPrint(
        'FCM registration completed for current user.',
      );
    } catch (e) {
      // FCM failure should not prevent login.
      debugPrint(
        'FCM registration failed: $e',
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login(
    String email,
    String password,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      final firebaseUser = _authService.firebaseUser;

      if (firebaseUser != null) {
        // Refresh user profile.
        _user = await _mapUser(firebaseUser);

        // Register this device for notifications.
        await _registerFcmToken();

        // Update last login time.
        final loginTime = DateTime.now();

        await _usersRef.child(firebaseUser.uid).update({
          'lastLogin': loginTime.toIso8601String(),
        });

        // Update local user model.
        _user = _user?.copyWith(
          lastLogin: loginTime,
        );

        // Save activity log.
        if (_user != null) {
          await _logActivity(
            action: 'Logged In',
            user: _user!,
          );
        }
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

  // ============================================================
  // REGISTER
  // ============================================================

  Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerWithEmailAndPassword(
        name,
        email,
        password,
      );

      // Register this new user/device for notifications.
      await _registerFcmToken();

      // Save registration activity.
      if (_user != null) {
        await _logActivity(
          action: 'Registered',
          user: _user!,
        );
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

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.signInWithGoogle();

      final firebaseUser = _authService.firebaseUser;

      if (firebaseUser != null) {
        // Refresh profile.
        _user = await _mapUser(firebaseUser);

        // Register this device for notifications.
        await _registerFcmToken();

        // Update last login time.
        final loginTime = DateTime.now();

        await _usersRef.child(firebaseUser.uid).update({
          'lastLogin': loginTime.toIso8601String(),
        });

        // Update local user model.
        _user = _user?.copyWith(
          lastLogin: loginTime,
        );

        // Save Google login activity.
        if (_user != null) {
          await _logActivity(
            action: 'Logged In with Google',
            user: _user!,
          );
        }
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

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

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

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    _setLoading(true);

    try {
      // Remove the current user's FCM token first.
      await FcmService.removeCurrentUserToken();

      // Sign out from Firebase Authentication.
      await _authService.signOut();

      _user = null;

      notifyListeners();
    } catch (e) {
      _setError(_cleanError(e));
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

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
        _setError('No user logged in');

        return false;
      }

      if (name != null && name.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(
          name.trim(),
        );
      }

      _user = _user?.copyWith(
        name: name,
        deviceId: deviceId,
        photoUrl: photoUrl,
      );

      if (_user != null) {
        await _usersRef
            .child(firebaseUser.uid)
            .update(_user!.toFirebase());
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

  // ============================================================
  // ACTIVITY LOGGING
  // ============================================================

  Future<void> _logActivity({
    required String action,
    required UserModel user,
  }) async {
    try {
      await _activityLogsRef.push().set({
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Activity logging should not stop login or registration.
      debugPrint(
        'Failed to save activity log: $e',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _setLoading(bool value) {
    _isLoading = value;

    notifyListeners();
  }

  void _setError(String error) {
    _error = error;

    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  String _cleanError(Object e) {
    return e
        .toString()
        .replaceAll('Exception:', '')
        .trim();
  }

  // ============================================================
  // MAP FIREBASE USER
  // ============================================================

  Future<UserModel> _mapUser(
    User firebaseUser,
  ) async {
    UserModel base = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'SmartDrip User',
      email: firebaseUser.email ?? '',
      createdAt: DateTime.now(),
    );

    try {
      final snapshot = await _usersRef
          .child(firebaseUser.uid)
          .get();

      final data = snapshot.value;

      if (data != null && data is Map) {
        final saved = UserModel.fromJson(
          Map<String, dynamic>.from(data),
        );

        base = base.copyWith(
          deviceId: saved.deviceId,
          photoUrl: saved.photoUrl,
          role: saved.role,
          createdAt: saved.createdAt,
          lastLogin: saved.lastLogin,
        );
      } else {
        await _usersRef
            .child(firebaseUser.uid)
            .update(base.toFirebase());
      }
    } catch (e) {
      debugPrint(
        'Failed to load user profile from Realtime Database: $e',
      );
    }

    return base;
  }
}