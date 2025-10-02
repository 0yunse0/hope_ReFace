class AppConfig {
  // 실서버 고정
  static const String apiBaseUrl =
      'https://asia-northeast3-hope-reface.cloudfunctions.net/api';

  static String signupPath() => '/auth/signup';
  static String firstfacePath() => '/expressions/initial';

  static String trainingSessionsPath() => '/training/sessions';
  static String trainingSessionDetailPath(String sid) =>
      '/training/sessions/$sid';
  static String saveSetPath(String sid) => '/training/sessions/$sid/sets';
  static String trainingRecommendationsPath() => '/training/recommendations';
}
