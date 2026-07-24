import 'package:backend/src/models/note.dart';
import 'package:postgres/postgres.dart';

class NoteRepository {
  NoteRepository(this.session);

  final Session session;

  Future<List<LeadNote>> listForLead(String leadId) async {
    final rows = await session.execute(
      Sql.named('''
        SELECT n.*, u.name AS author_name
        FROM lead_notes n
        LEFT JOIN users u ON u.id = n.author_id
        WHERE n.lead_id = @leadId
        ORDER BY n.created_at DESC
      '''),
      parameters: {'leadId': leadId},
    );
    return rows.map((r) => LeadNote.fromRow(r.toColumnMap())).toList();
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
