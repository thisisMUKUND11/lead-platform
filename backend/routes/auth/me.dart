import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /auth/me — returns the currently authenticated user.
Future<Response> onRequest(RequestContext context) async {
  allowMethods(context, [HttpMethod.get]);
  final principal = requireAuth(context);

  final db = context.read<Database>();
  final user = await UserRepository(db.session).findById(principal.userId);
  if (user == null) {
    throw ApiException.unauthorized('Account no longer exists');
  }
  return ok({'user': user.toJson()});
}
