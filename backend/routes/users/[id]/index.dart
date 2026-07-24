import 'package:backend/src/auth/password.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/http/guards.dart';
import 'package:backend/src/http/request_helpers.dart';
import 'package:backend/src/http/responses.dart';
import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  return switch (context.request.method) {
    HttpMethod.patch => _patch(context, id),
    HttpMethod.delete => _delete(context, id),
    _ => throw ApiException(405, 'Method not allowed', code: 'method_not_allowed'),
  };
}

/// PATCH /users/:id — admin only. Update a member's name/role and/or reset
/// their password. Passwords are stored hashed and can never be read back.
Future<Response> _patch(RequestContext context, String id) async {
  final principal = requireAdmin(context);

  final db = context.read<Database>();
  final repo = UserRepository(db.session);
  final existing = await repo.findById(id);
  if (existing == null) {
    throw ApiException.notFound('User not found');
  }

  final body = await readJsonBody(context);
  final name = (body['name'] as String?)?.trim();
  final roleName = (body['role'] as String?)?.trim();
  final password = body['password'] as String?;

  if (name != null && name.isEmpty) {
    throw ApiException.badRequest('name cannot be empty');
  }

  UserRole? role;
  if (roleName != null) {
    if (roleName != 'admin' && roleName != 'member') {
      throw ApiException.badRequest("role must be 'admin' or 'member'");
    }
    role = UserRole.fromString(roleName);
    // Prevent an admin from removing their own admin access (self-lockout).
    if (id == principal.userId && role != existing.role) {
      throw ApiException.badRequest('You cannot change your own role');
    }
  }

  String? passwordHash;
  if (password != null) {
    if (password.length < 6) {
      throw ApiException.badRequest('password must be at least 6 characters');
    }
    passwordHash = hashPassword(password);
  }

  if (name == null && role == null && passwordHash == null) {
    throw ApiException.badRequest('No fields to update');
  }

  final updated = await repo.update(
    id,
    name: name,
    role: role,
    passwordHash: passwordHash,
  );
  return ok({'user': updated.toJson()});
}

/// DELETE /users/:id — admin only. Cannot delete yourself or the last admin.
/// Leads/notes/activities keep their history (FKs are set null, not cascaded).
Future<Response> _delete(RequestContext context, String id) async {
  final principal = requireAdmin(context);

  final db = context.read<Database>();
  final repo = UserRepository(db.session);
  final existing = await repo.findById(id);
  if (existing == null) {
    throw ApiException.notFound('User not found');
  }
  if (id == principal.userId) {
    throw ApiException.badRequest('You cannot delete your own account');
  }
  if (existing.isAdmin && await repo.adminCount() <= 1) {
    throw ApiException.badRequest('Cannot delete the last admin');
  }

  await repo.delete(id);
  return noContent();
}
