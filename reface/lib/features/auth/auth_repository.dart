import '../../core/storage/token_storage.dart';
import 'data/auth_api.dart';

class AuthRepository {
  final _api = AuthApi();

  Future<void> login(String email, String password) async {
    final res = await _api.login(email, password); // { accessToken: "...", profile: {...} }
    final token = res['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('로그인 응답에 accessToken이 없습니다.');
    }
    await TokenStorage.write(token);
  }

  Future<void> logout() async {
    await _api.logout();
    await TokenStorage.clear();
  }
}
