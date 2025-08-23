class LoginResponse {
  final String accessToken;
  final Map<String, dynamic>? profile;
  const LoginResponse({required this.accessToken, this.profile});

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      LoginResponse(accessToken: json['accessToken'], profile: json['profile']);
}
