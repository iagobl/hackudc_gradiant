import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CloudAuthService {
  const CloudAuthService();

  SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
