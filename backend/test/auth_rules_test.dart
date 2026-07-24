// Test code reads dynamic JSON and passes explicit args for clarity.
// ignore_for_file: avoid_dynamic_calls, avoid_redundant_argument_values

import 'dart:convert';

import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/auth/lead_access.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

import '../routes/auth/login.dart' as login_route;
import '../routes/leads/index.dart' as leads_route;
import '../routes/users/index.dart' as users_route;
import 'helpers/test_context.dart';
import 'helpers/test_harness.dart';

Future<(int, dynamic)> _read(Response r) async {
  final body = await r.body();
  return (r.statusCode, body.isEmpty ? null : jsonDecode(body));
}

Matcher _throwsApi(int status) => throwsA(
      isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
    );

void main() {
  late TestHarness h;

  setUpAll(() async => h = await TestHarness.start());
  tearDownAll(() async => h.dispose());
  setUp(() async => h.reset());

  group('Authentication', () {
    test('login with correct credentials returns a token', () async {
      await h.createUser(
        email: 'admin@test.io',
        name: 'Admin',
        role: UserRole.admin,
        password: 'Secret123!',
      );
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        jsonBody: {'email': 'admin@test.io', 'password': 'Secret123!'},
      );

      final (status, body) = await _read(await login_route.onRequest(ctx));

      expect(status, 200);
      expect(body['token'], isA<String>());
      expect(body['user']['role'], 'admin');
      // token must verify back to the same principal
      final principal = h.jwt.verify(body['token'] as String);
      expect(principal, isNotNull);
      expect(principal!.role, UserRole.admin);
    });

    test('login with wrong password is rejected with 401', () async {
      await h.createUser(
        email: 'admin@test.io',
        name: 'Admin',
        role: UserRole.admin,
        password: 'Secret123!',
      );
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        jsonBody: {'email': 'admin@test.io', 'password': 'WRONG'},
      );
      expect(() => login_route.onRequest(ctx), _throwsApi(401));
    });

    test('login with unknown email is rejected with 401', () async {
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        jsonBody: {'email': 'nobody@test.io', 'password': 'whatever'},
      );
      expect(() => login_route.onRequest(ctx), _throwsApi(401));
    });
  });

  group('Authorization rules', () {
    test('listing leads without a token returns 401', () async {
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'GET',
        path: '/leads',
        // no principal => unauthenticated
      );
      expect(() => leads_route.onRequest(ctx), _throwsApi(401));
    });

    test('a member cannot create users (admin-only) -> 403', () async {
      final member = await h.createUser(
        email: 'm@test.io',
        name: 'Member',
        role: UserRole.member,
      );
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        path: '/users',
        principal: AuthPrincipal(userId: member.id, role: UserRole.member),
        jsonBody: {'email': 'x@test.io', 'name': 'X', 'password': 'pw12345'},
      );
      expect(() => users_route.onRequest(ctx), _throwsApi(403));
    });

    test('a member cannot list users (admin-only) -> 403', () async {
      final member = await h.createUser(
        email: 'm@test.io',
        name: 'Member',
        role: UserRole.member,
      );
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'GET',
        path: '/users',
        principal: AuthPrincipal(userId: member.id, role: UserRole.member),
      );
      expect(() => users_route.onRequest(ctx), _throwsApi(403));
    });

    test('a member cannot access a lead assigned to someone else -> 403',
        () async {
      final owner = await h.createUser(
        email: 'owner@test.io',
        name: 'Owner',
        role: UserRole.member,
      );
      final other = await h.createUser(
        email: 'other@test.io',
        name: 'Other',
        role: UserRole.member,
      );
      final admin = await h.createUser(
        email: 'admin@test.io',
        name: 'Admin',
        role: UserRole.admin,
      );
      final lead = await LeadRepository(h.db.session).create(
        name: 'Lead',
        email: 'lead@test.io',
      );
      await LeadRepository(h.db.session).assign(lead.id, owner.id);

      // The assigned member can access it.
      final ownerCtx = buildTestContext(db: h.db, jwt: h.jwt, method: 'GET');
      final ownerResult = await loadAccessibleLead(
        ownerCtx,
        lead.id,
        principal: AuthPrincipal(userId: owner.id, role: UserRole.member),
      );
      expect(ownerResult.lead.id, lead.id);

      // A different member is forbidden.
      final otherCtx = buildTestContext(db: h.db, jwt: h.jwt, method: 'GET');
      expect(
        () => loadAccessibleLead(
          otherCtx,
          lead.id,
          principal: AuthPrincipal(userId: other.id, role: UserRole.member),
        ),
        _throwsApi(403),
      );

      // Admins can access any lead.
      final adminCtx = buildTestContext(db: h.db, jwt: h.jwt, method: 'GET');
      final adminResult = await loadAccessibleLead(
        adminCtx,
        lead.id,
        principal: AuthPrincipal(userId: admin.id, role: UserRole.admin),
      );
      expect(adminResult.lead.id, lead.id);
    });

    test('members only see their own assigned leads in the list', () async {
      final member = await h.createUser(
        email: 'm@test.io',
        name: 'Member',
        role: UserRole.member,
      );
      final mine = await LeadRepository(h.db.session)
          .create(name: 'Mine', email: 'mine@test.io');
      await LeadRepository(h.db.session).assign(mine.id, member.id);
      await LeadRepository(h.db.session)
          .create(name: 'NotMine', email: 'nm@test.io');

      final memberCtx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'GET',
        path: '/leads',
        principal: AuthPrincipal(userId: member.id, role: UserRole.member),
      );
      final (_, memberBody) = await _read(await leads_route.onRequest(memberCtx));
      expect(memberBody['pagination']['total'], 1);
      expect(memberBody['data'][0]['name'], 'Mine');

      // Admin sees both.
      final admin = await h.createUser(
        email: 'a@test.io',
        name: 'Admin',
        role: UserRole.admin,
      );
      final adminCtx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'GET',
        path: '/leads',
        principal: AuthPrincipal(userId: admin.id, role: UserRole.admin),
      );
      final (_, adminBody) = await _read(await leads_route.onRequest(adminCtx));
      expect(adminBody['pagination']['total'], 2);
    });
  });
}
