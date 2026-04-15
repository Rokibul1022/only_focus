import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/user_repository.dart';
import '../core/services/cache_service.dart';
import '../core/services/notes_service.dart';

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// User profile provider
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return UserRepository().streamUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserRepository _userRepo = UserRepository();
  final CacheService _cache = CacheService();
  final NotesService _notes = NotesService();
  
  String? _previousUserId;
  bool _isSigningOut = false;
  
  AuthService(this._ref) {
    // Listen to auth state changes and clear local data on user change
    _auth.authStateChanges().listen((user) {
      if (!_isSigningOut) {
        _handleUserChange(user);
      }
    });
  }
  
  Future<void> _handleUserChange(User? user) async {
    final currentUserId = user?.uid;
    
    // If user changed (not just initial load or sign out)
    if (_previousUserId != null && _previousUserId != currentUserId && currentUserId != null) {
      print('User changed from $_previousUserId to $currentUserId, clearing local data');
      await _clearLocalData();
    }
    
    _previousUserId = currentUserId;
  }
  
  Future<void> _clearLocalData() async {
    try {
      // Clear all articles and notes from Isar
      final db = await _cache.isar;
      await db.writeTxn(() async {
        await db.clear();
      });
      print('Local data cleared successfully');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }
  
  User? get currentUser => _auth.currentUser;
  
  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
      
      // Create user profile in Firestore
      if (credential.user != null) {
        try {
          final profile = UserProfile.initial(
            uid: credential.user!.uid,
            displayName: displayName,
            email: email,
          );
          await _userRepo.createUserProfile(profile);
        } catch (firestoreError) {
          // If Firestore fails, still return success but log error
          print('Firestore error: $firestoreError');
        }
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered. Please sign in instead.');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 6 characters.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        default:
          throw Exception('Sign up failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }
  
  // Email/Password Sign In
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last active or create profile if doesn't exist
      if (credential.user != null) {
        try {
          await _userRepo.updateLastActive(credential.user!.uid);
        } catch (e) {
          // Profile might not exist, create it
          final profile = UserProfile.initial(
            uid: credential.user!.uid,
            displayName: credential.user!.displayName ?? 'User',
            email: email,
          );
          await _userRepo.createUserProfile(profile);
        }
      }
      
      return credential;
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }
  
  // Google Sign In
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    final userCredential = await _auth.signInWithCredential(credential);
    
    // Check if this is a new user
    if (userCredential.additionalUserInfo?.isNewUser ?? false) {
      // Create user profile
      if (userCredential.user != null) {
        final profile = UserProfile.initial(
          uid: userCredential.user!.uid,
          displayName: userCredential.user!.displayName ?? 'User',
          email: userCredential.user!.email ?? '',
        );
        await _userRepo.createUserProfile(profile);
      }
    } else {
      // Update last active
      if (userCredential.user != null) {
        await _userRepo.updateLastActive(userCredential.user!.uid);
      }
    }
    
    return userCredential;
  }
  
  // Anonymous Sign In
  Future<UserCredential> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      
      // Create anonymous user profile only if it doesn't exist
      if (credential.user != null) {
        try {
          final existingProfile = await _userRepo.getUserProfile(credential.user!.uid);
          if (existingProfile == null) {
            final profile = UserProfile.initial(
              uid: credential.user!.uid,
              displayName: 'Guest',
              email: '',
            );
            await _userRepo.createUserProfile(profile);
          }
        } catch (e) {
          // Profile doesn't exist, create it
          final profile = UserProfile.initial(
            uid: credential.user!.uid,
            displayName: 'Guest',
            email: '',
          );
          await _userRepo.createUserProfile(profile);
        }
      }
      
      return credential;
    } catch (e) {
      throw Exception('Anonymous sign-in failed: ${e.toString()}');
    }
  }
  
  // Sign Out
  Future<void> signOut() async {
    try {
      _isSigningOut = true;
      await _clearLocalData();
      await _googleSignIn.signOut();
      await _auth.signOut();
      _previousUserId = null;
    } finally {
      _isSigningOut = false;
    }
  }
  
  // Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
