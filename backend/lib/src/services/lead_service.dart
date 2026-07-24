import 'package:backend/src/db/database.dart';
import 'package:backend/src/models/lead.dart';
import 'package:backend/src/models/note.dart';
import 'package:backend/src/repositories/activity_repository.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/repositories/note_repository.dart';

/// Coordinates lead mutations with their activity-trail entries so that the
/// data change and its audit record always commit together (or not at all).
class LeadService {
  LeadService(this._db);

  final Database _db;

  /// Creates a lead and records a `created` activity in one transaction.
  /// [actorId] is null for public capture-form submissions.
  Future<Lead> createLead({
    required String name,
    required String email,
    String? phone,
    String? company,
    String? source,
    String? actorId,
  }) {
    return _db.transaction((tx) async {
      final lead = await LeadRepository(tx).create(
        name: name,
        email: email,
        phone: phone,
        company: company,
        source: source,
        createdBy: actorId,
      );
      await ActivityRepository(tx).log(
        leadId: lead.id,
        type: 'created',
        actorId: actorId,
        metadata: {'source': source ?? 'public_form'},
      );
      return lead;
    });
  }

  /// Applies field updates. If `status` changes, logs `status_changed`
  /// (with from/to); otherwise logs a generic `updated`.
  Future<Lead> updateLead({
    required Lead current,
    required Map<String, Object?> fields,
    required String actorId,
  }) {
    return _db.transaction((tx) async {
      final updated = await LeadRepository(tx).updateFields(current.id, fields);
      final activities = ActivityRepository(tx);
      if (fields.containsKey('status') &&
          fields['status'] != current.status.wire) {
        await activities.log(
          leadId: current.id,
          type: 'status_changed',
          actorId: actorId,
          metadata: {'from': current.status.wire, 'to': updated.status.wire},
        );
      } else {
        await activities.log(
          leadId: current.id,
          type: 'updated',
          actorId: actorId,
          metadata: {'fields': fields.keys.toList()},
        );
      }
      return updated;
    });
  }

  /// Assigns (or unassigns, when [userId] is null) a lead and logs it.
  Future<Lead> assignLead({
    required String leadId,
    required String? userId,
    required String actorId,
  }) {
    return _db.transaction((tx) async {
      final lead = await LeadRepository(tx).assign(leadId, userId);
      await ActivityRepository(tx).log(
        leadId: leadId,
        type: 'assigned',
        actorId: actorId,
        metadata: {'assignedTo': userId},
      );
      return lead;
    });
  }

  /// Adds a note and logs a `note_added` activity in one transaction.
  Future<LeadNote> addNote({
    required String leadId,
    required String body,
    required String actorId,
  }) {
    return _db.transaction((tx) async {
      final note = await NoteRepository(tx).create(
        leadId: leadId,
        body: body,
        authorId: actorId,
      );
      await ActivityRepository(tx).log(
        leadId: leadId,
        type: 'note_added',
        actorId: actorId,
        metadata: {'noteId': note.id},
      );
      return note;
    });
  }
}
