import '../models.dart';
import 'api_client.dart';

/// Typed wrapper over [ApiClient] exposing the platform's endpoints as
/// strongly-typed methods returning domain models.
class ApiService {
  ApiService(this.client);

  final ApiClient client;

  // ── Auth ──────────────────────────────────────────────────────
  Future<({String token, User user})> login(
    String email,
    String password,
  ) async {
    final res = await client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;
    return (
      token: res['token'] as String,
      user: User.fromJson(res['user'] as Map<String, dynamic>),
    );
  }

  Future<User> me() async {
    final res = await client.get('/auth/me') as Map<String, dynamic>;
    return User.fromJson(res['user'] as Map<String, dynamic>);
  }

  // ── Leads ─────────────────────────────────────────────────────
  Future<Paginated<Lead>> listLeads({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String? assignedTo,
  }) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};
    if (status != null) query['status'] = status;
    if (search != null && search.isNotEmpty) query['q'] = search;
    if (assignedTo != null) query['assigned_to'] = assignedTo;
    final res = await client.get('/leads', query: query) as Map<String, dynamic>;
    return Paginated.fromJson(res, Lead.fromJson);
  }

  /// Public capture form submission (no auth required).
  Future<Lead> createLead(Map<String, dynamic> data) async {
    final res = await client.post('/leads', body: data) as Map<String, dynamic>;
    return Lead.fromJson(res['lead'] as Map<String, dynamic>);
  }

  Future<Lead> getLead(String id) async {
    final res = await client.get('/leads/$id') as Map<String, dynamic>;
    return Lead.fromJson(res['lead'] as Map<String, dynamic>);
  }

  Future<Lead> updateLead(String id, Map<String, dynamic> fields) async {
    final res =
        await client.patch('/leads/$id', body: fields) as Map<String, dynamic>;
    return Lead.fromJson(res['lead'] as Map<String, dynamic>);
  }

  Future<Lead> assignLead(String id, String? userId) async {
    final res = await client.post(
      '/leads/$id/assign',
      body: {'userId': userId},
    ) as Map<String, dynamic>;
    return Lead.fromJson(res['lead'] as Map<String, dynamic>);
  }

  Future<void> deleteLead(String id) => client.delete('/leads/$id');

  Future<List<LeadNote>> listNotes(String leadId) async {
    final res =
        await client.get('/leads/$leadId/notes') as Map<String, dynamic>;
    return (res['data'] as List)
        .map((e) => LeadNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LeadNote> addNote(String leadId, String body) async {
    final res = await client.post(
      '/leads/$leadId/notes',
      body: {'body': body},
    ) as Map<String, dynamic>;
    return LeadNote.fromJson(res['note'] as Map<String, dynamic>);
  }

  Future<List<Activity>> listActivities(String leadId) async {
    final res =
        await client.get('/leads/$leadId/activities') as Map<String, dynamic>;
    return (res['data'] as List)
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Users (admin) ─────────────────────────────────────────────
  Future<List<User>> listUsers() async {
    final res = await client.get('/users') as Map<String, dynamic>;
    return (res['data'] as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<User> createUser({
    required String email,
    required String name,
    required String password,
    required String role,
  }) async {
    final res = await client.post('/users', body: {
      'email': email,
      'name': name,
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
    return User.fromJson(res['user'] as Map<String, dynamic>);
  }

  /// Admin: update a member's name/role and/or reset their password.
  /// Omit [password] (or pass empty) to leave the password unchanged.
  Future<User> updateUser(
    String id, {
    String? name,
    String? role,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = role;
    if (password != null && password.isNotEmpty) body['password'] = password;
    final res =
        await client.patch('/users/$id', body: body) as Map<String, dynamic>;
    return User.fromJson(res['user'] as Map<String, dynamic>);
  }

  /// Admin: remove a team member.
  Future<void> deleteUser(String id) => client.delete('/users/$id');
}
