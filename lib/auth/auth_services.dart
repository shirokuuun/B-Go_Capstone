import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Google Sign In
  Future<UserCredential?> SignInWithGoogle() async {
    // pop up a Google Sign In window
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // if the user cancels the sign in, return null
    if (googleUser == null) {
      return null;
    }

    //obtain details from the Google sign in
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential =
        await _auth.signInWithCredential(credential);

    // Save user info to Firestore
    final user = userCredential.user;
    if (user != null) {
      final email = user.email ?? googleUser.email;
      final name = email.split('@')[0]; // Name = email before "@"
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
      }, SetOptions(merge: true));
    }

    return userCredential;
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  //register page
  Future<String?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty) {
      return "Please enter your full name.";
    }
    if (email.trim().isEmpty) {
      return "Please enter your email address.";
    }
    if (password.trim().isEmpty) {
      return "Please enter a password.";
    }
    if (confirmPassword.trim().isEmpty) {
      return "Please confirm your password.";
    }
    if (password.trim() != confirmPassword.trim()) {
      return "Passwords do not match.";
    }
    // Basic email format check
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");
    if (!emailRegex.hasMatch(email.trim())) {
      return "Please enter a valid email address.";
    }
    if (password.length < 6) {
      return "Password must be at least 6 characters long.";
    }
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
        });
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already in use.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        default:
          message = 'Registration failed. Please try again.';
      }
      return message;
    } catch (e) {
      return "An error occurred. Please try again.";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
