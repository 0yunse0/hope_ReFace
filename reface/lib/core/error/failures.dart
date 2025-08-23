sealed class Failure implements Exception {
  final String message;
  const Failure(this.message);
}
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class AuthFailure extends Failure { const AuthFailure(super.message); }
