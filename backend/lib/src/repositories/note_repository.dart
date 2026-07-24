import 'package:backend/src/models/note.dart';
import 'package:backend/src/repositories/page.dart';
import 'package:postgres/postgres.dart';

class NoteRepository {
  NoteRepository(this.session);

  final Session session;

  Future<Page<LeadNote>> listForLead(
    String leadId, {
    int page = 1,
    int limit = 50,
  }) async {
    final countResult = await session.execute(
      Sql.named('SELECT COUNT(*) AS n FROM lead_notes WHERE lead_id = @leadId'),
      parameters: {'leadId': leadId},
    );
    final total = (countResult.first.toColumnMap()['n'] as int?) ?? 0;

    final offset = (page - 1) * limit;
    final rows = await session.execute(
      Sql.named('''
        SELECT n.*, u.name AS author_name
        FROM lead_notes n
        LEFT JOIN users u ON u.id = n.author_id
        WHERE n.lead_id = @leadId
        ORDER BY n.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {'leadId': leadId, 'limit': limit, 'offset': offset},
    );
    return Page(
      items: rows.map((r) => LeadNote.fromRow(r.toColumnMap())).toList(),
      total: total,
      page: page,
      limit: limit,
    );
  }

  Future<LeadNote> create({
    required String leadId,
    required String body,
    String? authorId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        INSERT INTO lead_notes (lead_id, author_id, body)
        VALUES (@leadId, @authorId, @body)
        RETURNING *
      '''),
      parameters: {'leadId': leadId, 'authorId': authorId, 'body': body},
    );
    return LeadNote.fromRow(result.first.toColumnMap());
  }
}
