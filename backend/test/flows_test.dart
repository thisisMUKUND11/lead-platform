// Test code reads dynamic JSON and passes explicit args for clarity.
// ignore_for_file: avoid_dynamic_calls, avoid_redundant_argument_values

import 'dart:convert';

import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/activity_repository.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/repositories/note_repository.dart';
import 'package:backend/src/services/lead_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:test/test.dart';

import '../routes/leads/index.dart' as leads_route;
import 'helpers/test_context.dart';
import 'helpers/test_harness.dart';

Future<(int, dynamic)> _read(Response r) async {
  final body = await r.body();
  return (r.statusCode, body.isEmpty ? null : jsonDecode(body));
}

void main() {
  late TestHarness h;

  setUpAll(() async => h = await TestHarness.start());
  tearDownAll(() async => h.dispose());
  setUp(() async => h.reset());

  group('Core flow 1: public lead capture', () {
    test('creates a lead as "new" and logs a "created" activity', () async {
      // Public submission: no authenticated principal.
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        path: '/leads',
        jsonBody: {
          'name': 'Jordan Prospect',
          'email': 'jordan@lead.io',
          'company': 'Prospect Inc',
          'source': 'landing_page',
        },
      );

      final (status, body) = await _read(await leads_route.onRequest(ctx));

      expect(status, 201);
      final leadJson = body['lead'] as Map<String, dynamic>;
      expect(leadJson['status'], 'new');
      expect(leadJson['name'], 'Jordan Prospect');
      expect(leadJson['createdBy'], isNull); // anonymous

      // Persisted?
      final stored =
          await LeadRepository(h.db.session).findById(leadJson['id'] as String);
      expect(stored, isNotNull);
      expect(stored!.email, 'jordan@lead.io');

      // Activity trail has exactly one "created" entry.
      final activities =
          await ActivityRepository(h.db.session).listForLead(stored.id);
      expect(activities.items, hasLength(1));
      expect(activities.items.single.type, 'created');
    });

    test('rejects a submission with an invalid email (400)', () async {
      final ctx = buildTestContext(
        db: h.db,
        jwt: h.jwt,
        method: 'POST',
        path: '/leads',
        jsonBody: {'name': 'No Email', 'email': 'not-an-email'},
      );
      await expectLater(
        leads_route.onRequest(ctx),
        throwsA(isA<Object>()),
      );
    });
  });

  group('Core flow 2: assignment → status change → note → activity trail', () {
    test('records every lifecycle event in order', () async {
      final admin = await h.createUser(
        email: 'admin@flow.io',
        name: 'Admin',
        role: UserRole.admin,
      );
      final member = await h.createUser(
        email: 'member@flow.io',
        name: 'Member',
        role: UserRole.member,
      );
      final service = LeadService(h.db);

      // 1. Admin creates a lead.
      final lead = await service.createLead(
        name: 'Big Deal',
        email: 'buyer@bigdeal.io',
        source: 'referral',
        actorId: admin.id,
      );
      expect(lead.status.wire, 'new');

      // 2. Admin assigns it to the member.
      final assigned = await service.assignLead(
        leadId: lead.id,
        userId: member.id,
        actorId: admin.id,
      );
      expect(assigned.assignedTo, member.id);

      // 3. Member advances the status.
      final contacted = await service.updateLead(
        current: assigned,
        fields: {'status': 'contacted'},
        actorId: member.id,
      );
      expect(contacted.status.wire, 'contacted');

      // 4. Member adds a timestamped note.
      final note = await service.addNote(
        leadId: lead.id,
        body: 'Spoke with the buyer, sending a proposal.',
        actorId: member.id,
      );
      expect(note.body, contains('proposal'));

      // Note is persisted and attributed.
      final notes = await NoteRepository(h.db.session).listForLead(lead.id);
      expect(notes.items, hasLength(1));
      expect(notes.items.single.authorId, member.id);

      // Activity trail contains all four events (newest first).
      final activities =
          await ActivityRepository(h.db.session).listForLead(lead.id);
      final types = activities.items.map((a) => a.type).toList();
      expect(types, ['note_added', 'status_changed', 'assigned', 'created']);

      // The status_changed entry captures the transition detail.
      final statusChange =
          activities.items.firstWhere((a) => a.type == 'status_changed');
      expect(statusChange.metadata['from'], 'new');
      expect(statusChange.metadata['to'], 'contacted');
    });
  });
}
