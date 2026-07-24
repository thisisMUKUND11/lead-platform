import 'package:backend/src/auth/jwt_service.dart';
import 'package:backend/src/auth/password.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /auth/login  — exchange email + password for a JWT.
Future<Response> onRequest(RequestContext context) async {
  allowMethods(context, [HttpMethod.post]);

  final body = await readJsonBody(context);
  final email = (body['email'] as String?)?.trim();
  final password = body['password'] as String?;
  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    throw ApiException.badRequest('email and password are required');
  }

  final db = context.read<Database>();
  final user = await UserRepository(db.session).findByEmail(email);

  // Same error whether the email is unknown or the password is wrong, so we
  // don't leak which accounts exist.
  if (user == null ||
      user.passwordHash == null ||
      !verifyPassword(password, user.passwordHash!)) {
    throw ApiException.unauthorized('Invalid email or password');
  }

  final token = context.read<JwtService>().issue(user);
  return ok({'token': token, 'user': user.toJson()});
}
