import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<String> login(String email, String password) async {
    final json = await _api.post('/v1/auth/login', {
      'email': email.trim(),
      'password': password,
    }, authenticated: false);
    return parseModel(() {
      final token = json['access_token'] as String;
      if (token.isEmpty || json['token_type'] != 'bearer') {
        throw const FormatException();
      }
      return token;
    });
  }
}
