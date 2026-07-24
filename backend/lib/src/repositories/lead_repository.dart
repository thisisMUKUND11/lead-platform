import 'package:backend/src/models/lead.dart';
import 'package:backend/src/repositories/page.dart';
import 'package:postgres/postgres.dart';

/// Filters accepted by [LeadRepository.list]. All are optional (AND-combined).
class LeadFilter {
  const LeadFilter({
    this.status,
    this.assignedTo,
    this.source,
    this.search,
  });

  final String? status;
  final String? assignedTo;
  final String? source;

  /// Free-text search across name, email and company.
  final String? search;
}

class LeadRepository {
  LeadRepository(this.session);

  final Session session;

  // Reusable projection that joins the assignee's display name.
  static const _selectWithAssignee = '''
    SELECT l.*, au.name AS assigned_to_name
    FROM leads l
    LEFT JOIN users au ON au.id = l.assigned_to
  ''';

  Future<Page<Lead>> list({
    required LeadFilter filter,
    required int page,
    required int limit,
  }) async {
    final conditions = <String>[];
    final params = <String, Object?>{};

    // Columns are qualified with `l.` because the users join also exposes
    // name/email.
    if (filter.status != null) {
      conditions.add('l.status = @status');
      params['status'] = filter.status;
    }
    if (filter.assignedTo != null) {
      conditions.add('l.assigned_to = @assignedTo');
      params['assignedTo'] = filter.assignedTo;
    }
    if (filter.source != null) {
      conditions.add('l.source = @source');
      params['source'] = filter.source;
    }
    if (filter.search != null && filter.search!.trim().isNotEmpty) {
      conditions.add(
        '(l.name ILIKE @q OR l.email ILIKE @q OR l.company ILIKE @q)',
      );
      params['q'] = '%${filter.search!.trim()}%';
    }

    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final countResult = await session.execute(
      Sql.named('SELECT COUNT(*) AS n FROM leads l $where'),
      parameters: params,
    );
    final total = (countResult.first.toColumnMap()['n'] as int?) ?? 0;

    final offset = (page - 1) * limit;
    final rows = await session.execute(
      Sql.named('''
        $_selectWithAssignee
        $where
        ORDER BY l.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': limit, 'offset': offset},
    );

    return Page(
      items: rows.map((r) => Lead.fromRow(r.toColumnMap())).toList(),
      total: total,
      page: page,
      limit: limit,
    );
  }

  Future<Lead?> findById(String id) async {
    final result = await session.execute(
      Sql.named('$_selectWithAssignee WHERE l.id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Lead.fromRow(result.first.toColumnMap());
  }

  Future<Lead> create({
    required String name,
    required String email,
    String? phone,
    String? company,
    String? source,
    String? createdBy,
  }) async {
    final result = await session.execute(
      Sql.named('''
        WITH ins AS (
          INSERT INTO leads (name, email, phone, company, source, created_by)
          VALUES (@name, @email, @phone, @company, @source, @createdBy)
          RETURNING *
        )
        SELECT ins.*, au.name AS assigned_to_name
        FROM ins LEFT JOIN users au ON au.id = ins.assigned_to
      '''),
      parameters: {
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'source': source,
        'createdBy': createdBy,
      },
    );
    return Lead.fromRow(result.first.toColumnMap());
  }

  /// Updates mutable fields. Only keys present in [fields] are changed.
  Future<Lead> updateFields(String id, Map<String, Object?> fields) async {
    final allowed = {'name', 'email', 'phone', 'company', 'source', 'status'};
    final sets = <String>[];
    final params = <String, Object?>{'id': id};
    for (final entry in fields.entries) {
      if (!allowed.contains(entry.key)) continue;
      sets.add('${entry.key} = @${entry.key}');
      params[entry.key] = entry.value;
    }
    sets.add('updated_at = now()');
    final result = await session.execute(
      Sql.named('''
        WITH upd AS (
          UPDATE leads SET ${sets.join(', ')} WHERE id = @id RETURNING *
        )
        SELECT upd.*, au.name AS assigned_to_name
        FROM upd LEFT JOIN users au ON au.id = upd.assigned_to
      '''),
      parameters: params,
    );
    return Lead.fromRow(result.first.toColumnMap());
  }

  Future<Lead> assign(String id, String? userId) async {
    final result = await session.execute(
      Sql.named('''
        WITH upd AS (
          UPDATE leads SET assigned_to = @userId, updated_at = now()
          WHERE id = @id RETURNING *
        )
        SELECT upd.*, au.name AS assigned_to_name
        FROM upd LEFT JOIN users au ON au.id = upd.assigned_to
      '''),
      parameters: {'id': id, 'userId': userId},
    );
    return Lead.fromRow(result.first.toColumnMap());
  }

  Future<void> delete(String id) async {
    await session.execute(
      Sql.named('DELETE FROM leads WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
