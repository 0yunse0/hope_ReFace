import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reface/env.dart';

class ApiClient {
  final http.Client _http;
  final String? _baseUrlOverride;
  final String? _authTokenOverride;

  ApiClient({
    String? baseUrl,
    String? authToken,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrl,
        _authTokenOverride = authToken;

  /// 헤더 생성 (authTokenOverride 있으면 그걸 사용, 없으면 FirebaseAuth에서 가져옴)
  Future<Map<String, String>> _authHeaders() async {
    String token;
    if (_authTokenOverride != null) {
      token = _authTokenOverride!;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final t = await user.getIdToken();
      if (t == null) throw Exception('Failed to get ID token');
      token = t;
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// baseUrl: override 있으면 그걸 쓰고, 없으면 Env.baseUrl
  Uri _u(String path) => Uri.parse('${_baseUrlOverride ?? Env.baseUrl}$path');

  Future<http.Response> get(String path) async {
    final h = await _authHeaders();
    return _http.get(_u(path), headers: h);
  }

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final h = await _authHeaders();
    return _http.post(_u(path), headers: h, body: jsonEncode(body));
  }

  Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final h = await _authHeaders();
    return _http.put(_u(path), headers: h, body: jsonEncode(body));
  }
}
