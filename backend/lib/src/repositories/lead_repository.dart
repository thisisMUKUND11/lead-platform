import 'package:backend/src/models/lead.dart';
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

/// A page of results plus the total count of matching rows.
class Page<T> {
  const Page({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;

  int get totalPages => limit == 0 ? 0 : (total + limit - 1) ~/ limit;

  Map<String, dynamic> toJson(Object? Function(T) itemToJson) => {
        'data': items.map(itemToJson).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': totalPages,
        },
      };
}

class LeadRepository {
  LeadRepository(this.session);

  final Session session;

  Future<Page<Lead>> list({
    required LeadFilter filter,
    required int page,
    required int limit,
  }) async {
    final conditions = <String>[];
    final params = <String, Object?>{};

    if (filter.status != null) {
      conditions.add('status = @status');
      params['status'] = filter.status;
    }
    if (filter.assignedTo != null) {
      conditions.add('assigned_to = @assignedTo');
      params['assignedTo'] = filter.assignedTo;
    }
    if (filter.source != null) {
      conditions.add('source = @source');
      params['source'] = filter.source;
    }
    if (filter.search != null && filter.search!.trim().isNotEmpty) {
      conditions.add(
        '(name ILIKE @q OR email ILIKE @q OR company ILIKE @q)',
      );
      params['q'] = '%${filter.search!.trim()}%';
    }

    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final countResult = await session.execute(
      Sql.named('SELECT COUNT(*) AS n FROM leads $where'),
      parameters: params,
    );
    final total = (countResult.first.toColumnMap()['n'] as int?) ?? 0;

    final offset = (page - 1) * limit;
    final rows = await session.execute(
      Sql.named('''
        SELECT * FROM leads
        $where
        ORDER BY created_at DESC
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
      Sql.named('SELECT * FROM leads WHERE id = @id'),
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
        INSERT INTO leads (name, email, phone, company, source, created_by)
        VALUES (@name, @email, @phone, @company, @source, @createdBy)
        RETURNING *
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
      Sql.named('UPDATE leads SET ${sets.join(', ')} WHERE id = @id RETURNING *'),
      parameters: params,
    );
    return Lead.fromRow(result.first.toColumnMap());
  }

  Future<Lead> assign(String id, String? userId) async {
    final result = await session.execute(
      Sql.named('''
        UPDATE leads SET assigned_to = @userId, updated_at = now()
        WHERE id = @id RETURNING *
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
