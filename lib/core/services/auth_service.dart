import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> init() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUser = _mapUser(user);
    }
  }

  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _currentUser = _mapUser(credential.user!);
    return _currentUser!;
  }

  Future<UserModel> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name);

    _currentUser = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: credential.user!.email ?? '',
      createdAt: DateTime.now(),
    );
    return _currentUser!;
  }

  /// =========================
  /// GOOGLE SIGN-IN (WEB + MOBILE)
  /// =========================
  Future<UserModel> signInWithGoogle() async {
    UserCredential userCredential;

    if (kIsWeb) {
      // WEB: use Firebase's own popup flow (avoids google_sign_in_web COOP bug)
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      userCredential = await _auth.signInWithPopup(googleProvider);
    } else {
      // MOBILE (Android/iOS): keep using google_sign_in package
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("Google sign-in cancelled");
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCredential = await _auth.signInWithCredential(credential);
    }

    final user = userCredential.user!;
    _currentUser = _mapUser(user);
    return _currentUser!;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    _currentUser = null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  User? get firebaseUser => _auth.currentUser;

  UserModel _mapUser(User user) {
    return UserModel(
      uid: user.uid,
      name: user.displayName ?? 'SmartDrip User',
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );
  }
}
