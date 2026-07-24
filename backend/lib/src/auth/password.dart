import 'package:bcrypt/bcrypt.dart';

/// Hashes a plaintext password with bcrypt (per-hash random salt).
String hashPassword(String plaintext) =>
    BCrypt.hashpw(plaintext, BCrypt.gensalt());

/// Verifies a plaintext password against a stored bcrypt hash.
bool verifyPassword(String plaintext, String hash) {
  try {
    return BCrypt.checkpw(plaintext, hash);
  } catch (_) {
    // Malformed hash — treat as a failed match rather than throwing.
    return false;
  }
}
