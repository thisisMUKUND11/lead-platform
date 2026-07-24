import 'dart:convert';

/// An entry in a lead's activity trail (audit log).
class Activity {
  const Activity({
    required this.id,
    required this.leadId,
    required this.type,
    required this.metadata,
    required this.createdAt,
    this.actorId,
    this.actorName,
  });

  final String id;
  final String leadId;
  final String? actorId;

  /// Joined from users for display; null for public/system actions.
  final String? actorName;

  /// One of: created, status_changed, assigned, note_added, updated.
  final String type;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory Activity.fromRow(Map<String, dynamic> row) {
    final raw = row['metadata'];
    final Map<String, dynamic> meta;
    if (raw is Map) {
      meta = raw.cast<String, dynamic>();
    } else if (raw is String && raw.isNotEmpty) {
      meta = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } else {
      meta = <String, dynamic>{};
    }
    return Activity(
      id: row['id'].toString(),
      leadId: row['lead_id'].toString(),
      actorId: row['actor_id']?.toString(),
      actorName: row['actor_name'] as String?,
      type: row['type'] as String,
      metadata: meta,
      createdAt: row['created_at'] as DateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leadId': leadId,
        'actorId': actorId,
        'actorName': actorName,
        'type': type,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
      };
}
