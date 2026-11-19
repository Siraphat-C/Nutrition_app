import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// Local-only authentication for development and solo testing.
class LocalAuthService implements AuthService {
  LocalAuthService._(this._preferences)
    : _accounts = _readAccounts(_preferences),
      _currentEmail = _preferences.getString(_currentEmailKey);

  static const _accountsKey = 'nutrition_local_auth_accounts_v1';
  static const _currentEmailKey = 'nutrition_local_auth_current_email_v1';

  final SharedPreferences _preferences;
  final List<Map<String, dynamic>> _accounts;
  String? _currentEmail;

  static Future<LocalAuthService> create() async =>
      LocalAuthService._(await SharedPreferences.getInstance());

  static List<Map<String, dynamic>> _readAccounts(
    SharedPreferences preferences,
  ) {
    final stored = preferences.getString(_accountsKey);
    if (stored == null) return [];

    final decoded = jsonDecode(stored);
    if (decoded is! List) {
      throw const FormatException('ข้อมูลบัญชีทดสอบในเครื่องไม่ถูกต้อง');
    }
    return decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('ข้อมูลบัญชีทดสอบในเครื่องไม่ถูกต้อง');
      }
      final account = Map<String, dynamic>.from(item);
      for (final field in ['email', 'name', 'salt', 'passwordHash']) {
        if (account[field] is! String) {
          throw const FormatException('ข้อมูลบัญชีทดสอบในเครื่องไม่ครบ');
        }
      }
      return account;
    }).toList();
  }

  @override
  String? get currentEmail => _currentEmail;

  @override
  String? get currentName => _currentAccount?['name'] as String?;

  Map<String, dynamic>? get _currentAccount => _findAccount(_currentEmail);

  Map<String, dynamic>? _findAccount(String? email) {
    if (email == null) return null;
    final normalizedEmail = email.trim().toLowerCase();
    for (final account in _accounts) {
      if ((account['email'] as String).toLowerCase() == normalizedEmail) {
        return account;
      }
    }
    return null;
  }

  String _newSalt() => List<int>.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  String _passwordHash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<void> _saveAccounts() async {
    final saved = await _preferences.setString(
      _accountsKey,
      jsonEncode(_accounts),
    );
    if (!saved) throw StateError('บันทึกบัญชีทดสอบลงในเครื่องไม่สำเร็จ');
  }

  Future<void> _setCurrentEmail(String email) async {
    final saved = await _preferences.setString(_currentEmailKey, email);
    if (!saved) throw StateError('บันทึกสถานะเข้าสู่ระบบไม่สำเร็จ');
    _currentEmail = email;
  }

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_findAccount(normalizedEmail) != null) {
      throw StateError('อีเมลนี้มีบัญชีอยู่แล้ว');
    }

    final salt = _newSalt();
    _accounts.add({
      'email': normalizedEmail,
      'name': name.trim(),
      'salt': salt,
      'passwordHash': _passwordHash(salt, password),
    });
    await _saveAccounts();
    await _setCurrentEmail(normalizedEmail);
    return true;
  }

  @override
  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _findAccount(normalizedEmail);
    if (account == null ||
        account['passwordHash'] !=
            _passwordHash(account['salt'] as String, password)) {
      return false;
    }
    await _setCurrentEmail(normalizedEmail);
    return true;
  }

  @override
  Future<void> signOut() async {
    final removed = await _preferences.remove(_currentEmailKey);
    if (!removed) throw StateError('ออกจากระบบทดสอบไม่สำเร็จ');
    _currentEmail = null;
  }

  @override
  Future<String?> updateEmail(String email) async {
    final account = _currentAccount;
    if (account == null) return null;

    final normalizedEmail = email.trim().toLowerCase();
    final existingAccount = _findAccount(normalizedEmail);
    if (existingAccount != null && !identical(existingAccount, account)) {
      return null;
    }

    account['email'] = normalizedEmail;
    await _saveAccounts();
    await _setCurrentEmail(normalizedEmail);
    return normalizedEmail;
  }

  @override
  Future<void> updateName(String name) async {
    final account = _currentAccount;
    if (account == null) throw StateError('กรุณาเข้าสู่ระบบก่อนแก้ไขชื่อ');
    account['name'] = name.trim();
    await _saveAccounts();
  }

  @override
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final account = _currentAccount;
    if (account == null ||
        account['passwordHash'] !=
            _passwordHash(account['salt'] as String, oldPassword)) {
      return false;
    }

    final salt = _newSalt();
    account['salt'] = salt;
    account['passwordHash'] = _passwordHash(salt, newPassword);
    await _saveAccounts();
    return true;
  }
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
