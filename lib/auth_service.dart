import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthService {
  String? get currentEmail;
  String? get currentName;

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  });
  Future<bool> signIn({required String email, required String password});
  Future<void> signOut();
  Future<String?> updateEmail(String email);
  Future<void> updateName(String name);
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  String? get currentEmail => _client.auth.currentUser?.email;

  @override
  String? get currentName =>
      _client.auth.currentUser?.userMetadata?['name'] as String?;

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    return response.session != null;
  }

  @override
  Future<bool> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (error) {
      if (error.code == 'invalid_credentials') return false;
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<String?> updateEmail(String email) async {
    final response = await _client.auth.updateUser(
      UserAttributes(email: email),
    );
    return response.user?.email;
  }

  @override
  Future<void> updateName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'name': name}));
  }

  @override
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final email = currentEmail;
    if (email == null) return false;
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: oldPassword,
      );
    } on AuthException catch (error) {
      if (error.code == 'invalid_credentials') return false;
      rethrow;
    }

    await _client.auth.updateUser(UserAttributes(password: newPassword));
    return true;
  }
}
