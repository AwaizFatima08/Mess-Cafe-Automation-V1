import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches the current logged-in user's profile from the 'users' collection.
  /// This is the primary bridge between Firebase Auth (uid) and business logic.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  /// Updates specific fields in the user profile (e.g., display preferences).
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).update(data);
  }

  /// Streams the user profile for real-time UI updates (e.g., role changes).
  Stream<Map<String, dynamic>?> get userProfileStream {
    final User? user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db.collection('users').doc(user.uid).snapshots().map((snapshot) {
      return snapshot.data();
    });
  }

  /// RESTORE: signOut method for Admin and Employee Shells
  /// This fixes the undefined_method error in AdminDashboardShell.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Error during sign out: $e");
      rethrow;
    }
  }

  /// Helper to check if the current user has administrative privileges.
  Future<bool> isAdmin() async {
    final profile = await getCurrentUserProfile();
    if (profile == null) return false;
    
    final String role = profile['role'] ?? 'employee';
    return role == 'admin' || role == 'developer' || role == 'mess_manager';
  }
}
