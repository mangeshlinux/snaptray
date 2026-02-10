import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Stream of auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  // Check if user is logged in
  bool isLoggedIn() {
    return _client.auth.currentUser != null;
  }

  // Get current user email
  String? getUserEmail() {
    return _client.auth.currentUser?.email;
  }

  // Get current user ID
  String? getUserId() {
    return _client.auth.currentUser?.id;
  }

  // Login
  Future<bool> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user != null;
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  // Sign Up
  Future<bool> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      return response.user != null;
    } catch (e) {
      print('Sign Up Error: $e');
      return false;
    }
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('Reset Password Error: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Logout Error: $e');
    }
  }
}
