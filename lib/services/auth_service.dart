import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Login
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      final userData = query.docs.first.data();
      if (userData['password'] == password) {
        userData['uid'] = query.docs.first.id;
        return userData;
      }
      return null;
    } catch (e) {
      print("Auth Error: $e");
      return null;
    }
  }

  // Register
  Future<String> createUser(
    String email,
    String password,
    String name,
    String role,
  ) async {
    try {
      await _db.collection('users').add({
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return "Success";
    } catch (e) {
      return "Error: $e";
    }
  }

  // NEW: Update User Profile
  Future<bool> updateUser(
    String uid,
    String name,
    String email,
    String password,
  ) async {
    try {
      await _db.collection('users').doc(uid).update({
        'name': name,
        'email': email,
        'password': password, // Still plaintext as per your request
      });
      return true;
    } catch (e) {
      print("Update Error: $e");
      return false;
    }
  }
}
