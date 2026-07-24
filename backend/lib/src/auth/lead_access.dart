import 'package:backend/src/auth/auth_principal.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/http/api_exception.dart';
import 'package:backend/src/models/lead.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:dart_frog/dart_frog.dart';

/// True if [principal] may see/act on [lead]: admins can access any lead,
/// members only leads assigned to them.
bool canAccessLead(AuthPrincipal principal, Lead lead) =>
    principal.isAdmin || lead.assignedTo == principal.userId;

/// Loads a lead by id and enforces access:
/// - 401 if not authenticated
/// - 404 if the lead does not exist
/// - 403 if it exists but the member is not assigned to it
Future<({Lead lead, AuthPrincipal principal})> loadAccessibleLead(
  RequestContext context,
  String id, {
  required AuthPrincipal principal,
}) async {
  final db = context.read<Database>();
  final lead = await LeadRepository(db.session).findById(id);
  if (lead == null) {
    throw ApiException.notFound('Lead not found');
  }
  if (!canAccessLead(principal, lead)) {
    throw ApiException.forbidden('This lead is not assigned to you');
  }
  return (lead: lead, principal: principal);
}
