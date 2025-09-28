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
        'authMethod': 'google',
        'isEmailVerified': true, // Google emails are always verified
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return userCredential;
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final user = credential.user;
    if (user != null && !user.emailVerified) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email address before logging in.',
      );
    }
    
    // Update user in Firestore if they exist and email is verified
    if (user != null && user.emailVerified) {
      await _firestore.collection('users').doc(user.uid).update({
        'authMethod': 'email',
        'isEmailVerified': true, // Update verification status
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    return credential;
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
          'authMethod': 'email',
          'isEmailVerified': false, // Initially false until they verify email
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
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

  // Method to update email verification status
  Future<void> updateEmailVerificationStatus(String uid, bool isVerified) async {
    await _firestore.collection('users').doc(uid).update({
      'isEmailVerified': isVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Method to check and update verification status
  Future<void> checkAndUpdateEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload(); // Refresh user data
      final updatedUser = _auth.currentUser;
      if (updatedUser != null && updatedUser.emailVerified) {
        await updateEmailVerificationStatus(updatedUser.uid, true);
      }
    }
  }

  // Phone Authentication - Send OTP
  Future<void> sendOTP({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneVerificationFailed onVerificationFailed,
    required PhoneVerificationCompleted onVerificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout if needed
      },
    );
  }

  // Phone Authentication - Send OTP (Bypass reCAPTCHA)
  Future<void> sendOTPWithoutCaptcha({
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneVerificationFailed onVerificationFailed,
    required PhoneVerificationCompleted onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: null,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout
        },
      );
    } catch (e) {
      // Handle any unexpected errors
      onVerificationFailed(FirebaseAuthException(
        code: 'unknown-error',
        message: 'Failed to send OTP. Please try again.',
      ));
    }
  }

  // Phone Authentication - Verify OTP
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Save phone user to Firestore
  Future<void> savePhoneUserToFirestore({
    required String uid,
    required String phoneNumber,
    String? name,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'phone': phoneNumber,
      'name': name ?? phoneNumber, // Use phone number as name if no name provided
      'authMethod': 'phone',
      'isEmailVerified': false, // Phone users don't have email verification
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Check if phone number exists in Firestore
  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  // Get user by phone number
  Future<DocumentSnapshot?> getUserByPhone(String phoneNumber) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}