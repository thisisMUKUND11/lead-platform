import 'package:backend/src/models/user.dart';

/// The authenticated identity extracted from a verified JWT and attached to
/// the request context. This is the server's source of truth for "who is
/// making this request and what may they do".
class AuthPrincipal {
  const AuthPrincipal({required this.userId, required this.role});

  final String userId;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;
  bool get isMember => role == UserRole.member;
}
