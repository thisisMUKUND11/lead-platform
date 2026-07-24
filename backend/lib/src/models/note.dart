/// A timestamped note attached to a lead.
class LeadNote {
  const LeadNote({
    required this.id,
    required this.leadId,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.authorName,
  });

  final String id;
  final String leadId;
  final String? authorId;

  /// Joined from the users table for display; null if the author was removed.
  final String? authorName;
  final String body;
  final DateTime createdAt;

  factory LeadNote.fromRow(Map<String, dynamic> row) {
    return LeadNote(
      id: row['id'].toString(),
      leadId: row['lead_id'].toString(),
      authorId: row['author_id']?.toString(),
      authorName: row['author_name'] as String?,
      body: row['body'] as String,
      createdAt: row['created_at'] as DateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leadId': leadId,
        'authorId': authorId,
        'authorName': authorName,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };
}
