import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/platform/token_store.dart';
import '../data/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository, this._store);

  final AuthRepository _repository;
  final TokenStore _store;
  String? token;
  String? error;
  bool busy = false;
  bool restoring = true;

  Future<void> restore() async {
    try {
      final stored = await _store.read();
      if (stored != null) {
        _subject(stored);
        token = stored;
      }
    } catch (_) {
      error = 'Stored sign-in could not be restored. Please sign in again.';
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    if (busy) return false;
    if (!email.contains('@') || password.isEmpty) {
      error = 'Enter your email and password.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final issuedToken = await _repository.login(email, password);
      final issuedSubject = _subject(issuedToken);
      final current = token;
      if (current != null && _subject(current) != issuedSubject) {
        throw const ApiException(
          'account_mismatch',
          'Sign in with the original account to continue. To switch accounts, return and sign out first.',
        );
      }
      // Do not leave credentials/tokens in preferences, files, or application logs.
      await _store.write(issuedToken);
      token = issuedToken;
      return true;
    } catch (failure) {
      error = failure is ApiException
          ? failure.message
          : 'Could not sign in or securely store your access token. Please try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // Decode only to keep in-memory feature state bound to the same identity on
  // reauthentication. This is NOT token verification or authorization. The
  // backend verifies signatures/expiry and owns every ownership decision.
  String _subject(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) throw const FormatException();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map<String, dynamic> ||
          claims['sub'] is! String ||
          (claims['sub'] as String).isEmpty) {
        throw const FormatException();
      }
      return claims['sub'] as String;
    } on FormatException {
      throw const ApiException(
        'invalid_token',
        'The server returned an invalid sign-in response. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _store.clear();
      token = null;
      error = null;
    } catch (_) {
      error = 'Could not clear secure storage. Please try signing out again.';
    }
    notifyListeners();
  }
}
