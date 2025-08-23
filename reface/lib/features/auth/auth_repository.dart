import '../../core/storage/token_storage.dart';
import 'data/auth_api.dart';

class AuthRepository {
  final _api = AuthApi();

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password);
    final token = res['accessToken'] as String?;
    if (token == null) throw Exception('No accessToken in response');
    await TokenStorage.write(token);
  }

  Future<void> logout() async {
    await _api.logout();
    await TokenStorage.clear();
  }
}
