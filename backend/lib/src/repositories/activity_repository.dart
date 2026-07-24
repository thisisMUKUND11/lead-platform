import 'dart:convert';

import 'package:backend/src/models/activity.dart';
import 'package:postgres/postgres.dart';

class ActivityRepository {
  ActivityRepository(this.session);

  final Session session;

  Future<List<Activity>> listForLead(String leadId) async {
    final rows = await session.execute(
      Sql.named('''
        SELECT a.*, u.name AS actor_name
        FROM activities a
        LEFT JOIN users u ON u.id = a.actor_id
        WHERE a.lead_id = @leadId
        ORDER BY a.created_at DESC
      '''),
      parameters: {'leadId': leadId},
    );
    return rows.map((r) => Activity.fromRow(r.toColumnMap())).toList();
  }

  /// Appends an entry to a lead's activity trail.
  Future<void> log({
    required String leadId,
    required String type,
    String? actorId,
    Map<String, dynamic> metadata = const {},
  }) async {
    await session.execute(
      Sql.named('''
        INSERT INTO activities (lead_id, actor_id, type, metadata)
        VALUES (@leadId, @actorId, @type, @metadata::jsonb)
      '''),
      parameters: {
        'leadId': leadId,
        'actorId': actorId,
        'type': type,
        'metadata': jsonEncode(metadata),
      },
    );
  }
}
