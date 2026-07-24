// Domain models mirroring the JSON returned by the backend API.

enum UserRole { admin, member }

UserRole roleFromString(String value) =>
    value == 'admin' ? UserRole.admin : UserRole.member;

class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: roleFromString(json['role'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}

/// The lead lifecycle pipeline, in order.
enum LeadStatus {
  newLead('new', 'New'),
  contacted('contacted', 'Contacted'),
  qualified('qualified', 'Qualified'),
  proposal('proposal', 'Proposal'),
  won('won', 'Won'),
  lost('lost', 'Lost');

  const LeadStatus(this.wire, this.label);

  final String wire;
  final String label;

  static LeadStatus fromWire(String value) =>
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
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Lead.fromJson(Map<String, dynamic> json) => Lead(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        company: json['company'] as String?,
        source: json['source'] as String?,
        status: LeadStatus.fromWire(json['status'] as String),
        assignedTo: json['assignedTo'] as String?,
        createdBy: json['createdBy'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class LeadNote {
  const LeadNote({
    required this.id,
    required this.body,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String body;
  final String? authorName;
  final DateTime createdAt;

  factory LeadNote.fromJson(Map<String, dynamic> json) => LeadNote(
        id: json['id'] as String,
        body: json['body'] as String,
        authorName: json['authorName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.metadata,
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final String type;
  final Map<String, dynamic> metadata;
  final String? actorName;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as String,
        type: json['type'] as String,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
        actorName: json['actorName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A page of results plus pagination metadata.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return Paginated(
      items: (json['data'] as List)
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int,
      limit: pagination['limit'] as int,
      total: pagination['total'] as int,
      totalPages: pagination['totalPages'] as int,
    );
  }
}
