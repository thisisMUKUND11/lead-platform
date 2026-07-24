import 'dart:convert';

import 'package:backend/src/models/activity.dart';
import 'package:backend/src/repositories/page.dart';
import 'package:postgres/postgres.dart';

class ActivityRepository {
  ActivityRepository(this.session);

  final Session session;

  Future<Page<Activity>> listForLead(
    String leadId, {
    int page = 1,
    int limit = 50,
  }) async {
    final countResult = await session.execute(
      Sql.named('SELECT COUNT(*) AS n FROM activities WHERE lead_id = @leadId'),
      parameters: {'leadId': leadId},
    );
    final total = (countResult.first.toColumnMap()['n'] as int?) ?? 0;

    final offset = (page - 1) * limit;
    final rows = await session.execute(
      Sql.named('''
        SELECT a.*, u.name AS actor_name
        FROM activities a
        LEFT JOIN users u ON u.id = a.actor_id
        WHERE a.lead_id = @leadId
        ORDER BY a.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {'leadId': leadId, 'limit': limit, 'offset': offset},
    );
    return Page(
      items: rows.map((r) => Activity.fromRow(r.toColumnMap())).toList(),
      total: total,
      page: page,
      limit: limit,
    );
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
