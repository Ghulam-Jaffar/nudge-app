import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;
  final bool isNewUser;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.isNewUser = false,
  });

  factory AuthResult.success(User user, {bool isNewUser = false}) {
    return AuthResult(
      success: true,
      user: user,
      isNewUser: isNewUser,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult(
      success: false,
      errorMessage: message,
    );
  }
}

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          serverClientId: '951730653228-4qgh9b5a0jngscebnsemflaq7lsmaqoo.apps.googleusercontent.com',
        );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.failure('Failed to create account');
      }

      return AuthResult.success(credential.user!, isNewUser: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e.code));
    } catch (e) {
      debugPrint('Sign up error: $e');
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.failure('Failed to sign in');
      }

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e.code));
    } catch (e) {
      debugPrint('Sign in error: $e');
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google sign in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        return AuthResult.failure('Failed to sign in with Google');
      }

      // Check if this is a new user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      return AuthResult.success(userCredential.user!, isNewUser: isNewUser);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e.code));
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return AuthResult.failure('Failed to sign in with Google');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseAuthError(e.code));
    } catch (e) {
      debugPrint('Password reset error: $e');
      return AuthResult.failure('Failed to send password reset email');
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled';
      case 'weak-password':
        return 'Please use a stronger password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
