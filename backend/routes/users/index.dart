import 'package:backend/src/auth/password.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _list(context),
    HttpMethod.post => _create(context),
    _ => throw ApiException(405, 'Method not allowed', code: 'method_not_allowed'),
  };
}

/// GET /users — admin only. Used to populate the assignee picker.
Future<Response> _list(RequestContext context) async {
  requireAdmin(context);
  final db = context.read<Database>();
  final users = await UserRepository(db.session).listAll();
  return ok({'data': users.map((u) => u.toJson()).toList()});
}

/// POST /users — admin only. Create a team member (or another admin).
Future<Response> _create(RequestContext context) async {
  requireAdmin(context);
  final body = await readJsonBody(context);

  final email = (body['email'] as String?)?.trim().toLowerCase();
  final name = (body['name'] as String?)?.trim();
  final password = body['password'] as String?;
  final roleName = (body['role'] as String?)?.trim() ?? 'member';

  if (email == null || email.isEmpty) {
    throw ApiException.badRequest('email is required');
  }
  if (name == null || name.isEmpty) {
    throw ApiException.badRequest('name is required');
  }
  if (password == null || password.length < 6) {
    throw ApiException.badRequest('password must be at least 6 characters');
  }
  if (roleName != 'admin' && roleName != 'member') {
    throw ApiException.badRequest("role must be 'admin' or 'member'");
  }

  final db = context.read<Database>();
  final repo = UserRepository(db.session);
  if (await repo.findByEmail(email) != null) {
    throw ApiException.conflict('A user with that email already exists');
  }

  final user = await repo.create(
    email: email,
    name: name,
    passwordHash: hashPassword(password),
    role: UserRole.fromString(roleName),
  );
  return created({'user': user.toJson()});
}
