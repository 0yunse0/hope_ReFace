// lib/features/expressions/expressions_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:reface/core/network/api_client.dart';

class ExpressionsApi {
  final ApiClient _api;
  ExpressionsApi(this._api);

  /// expressions 구조:
  /// {
  ///   "neutral": { "leftMouth": {"x":..,"y":..}, ... 8개 },
  ///   "smile":   {...},
  ///   "angry":   {...},
  ///   "sad":     {...}
  /// }
  Future<bool> saveInitial(Map<String, dynamic> expressions) async {
    final res = await _api.post('/expressions/initial', {
      'expressions': expressions,
    });
    if (res.statusCode == 200) return true;
    throw Exception('saveInitial failed: ${res.statusCode} ${res.body}');
  }
}
