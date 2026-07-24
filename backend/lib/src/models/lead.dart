/// The lead lifecycle pipeline. Order matters for UI display.
enum LeadStatus {
  newLead('new'),
  contacted('contacted'),
  qualified('qualified'),
  proposal('proposal'),
  won('won'),
  lost('lost');

  const LeadStatus(this.wire);

  /// The value stored in the database / used on the wire.
  final String wire;

  static bool isValid(String value) =>
      LeadStatus.values.any((s) => s.wire == value);

  static LeadStatus fromString(String value) =>
      LeadStatus.values.firstWhere((s) => s.wire == value);
}

class Lead {
  const Lead({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.company,
    this.source,
    this.assignedTo,
    this.assignedToName,
    this.createdBy,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? company;
  final String? source;
  final LeadStatus status;
  final String? assignedTo;

  /// Joined from users for display; null when unassigned or the user is gone.
  final String? assignedToName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Lead.fromRow(Map<String, dynamic> row) {
    return Lead(
      id: row['id'].toString(),
      name: row['name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String?,
      company: row['company'] as String?,
      source: row['source'] as String?,
      status: LeadStatus.fromString(row['status'] as String),
      assignedTo: row['assigned_to']?.toString(),
      assignedToName: row['assigned_to_name'] as String?,
      createdBy: row['created_by']?.toString(),
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'source': source,
        'status': status.wire,
        'assignedTo': assignedTo,
        'assignedToName': assignedToName,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
