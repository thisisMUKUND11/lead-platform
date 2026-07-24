import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/models/user.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Issues and verifies signed JWTs (HS256). Self-managed: we own the secret,
/// the claims, and the verification — no third-party auth provider.
class JwtService {
  JwtService({required this.secret, required this.expiresMinutes});

  final String secret;
  final int expiresMinutes;

  /// Signs an access token for [user] containing subject + role claims.
  String issue(User user) {
    final jwt = JWT(
      {'role': user.role.name},
      subject: user.id,
    );
    return jwt.sign(
      SecretKey(secret),
      expiresIn: Duration(minutes: expiresMinutes),
    );
  }

  /// Verifies [token] and returns the principal, or null if invalid/expired.
  AuthPrincipal? verify(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      final payload = jwt.payload as Map<String, dynamic>;
      final userId = jwt.subject;
      final roleName = payload['role'] as String?;
      if (userId == null || roleName == null) return null;
      return AuthPrincipal(
        userId: userId,
        role: UserRole.fromString(roleName),
      );
    } catch (_) {
      return null;
    }
  }
}
