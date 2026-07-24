import 'dart:io';

import 'package:backend/src/auth/password.dart';
import 'package:backend/src/config/env.dart';
import 'package:backend/src/db/database.dart';
import 'package:backend/src/models/user.dart';
import 'package:backend/src/repositories/lead_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/services/lead_service.dart';

/// Seeds demo users (one per role) and a handful of sample leads.
/// Idempotent: existing users are left untouched and sample leads are only
/// created when the leads table is empty.
///
/// Usage (from backend/):  dart run bin/seed.dart
Future<void> main() async {
  const adminEmail = 'admin@demo.test';
  const adminPassword = 'Admin123!';
  const memberEmail = 'member@demo.test';
  const memberPassword = 'Member123!';

  final db = await Database.connect(Env.instance.databaseUrl);
  final users = UserRepository(db.session);

  final admin = await users.findByEmail(adminEmail) ??
      await users.create(
        email: adminEmail,
        name: 'Admin User',
        passwordHash: hashPassword(adminPassword),
        role: UserRole.admin,
      );
  final member = await users.findByEmail(memberEmail) ??
      await users.create(
        email: memberEmail,
        name: 'Member User',
        passwordHash: hashPassword(memberPassword),
        role: UserRole.member,
      );

  final leads = LeadRepository(db.session);
  final existing = await leads.list(filter: const LeadFilter(), page: 1, limit: 1);
  if (existing.total == 0) {
    final service = LeadService(db);

    final acme = await service.createLead(
      name: 'Jane Buyer',
      email: 'jane@acme.test',
      company: 'Acme Corp',
      source: 'website',
      actorId: admin.id,
    );
    final assigned = await service.assignLead(
      leadId: acme.id,
      userId: member.id,
      actorId: admin.id,
    );
    await service.updateLead(
      current: assigned,
      fields: {'status': 'contacted'},
      actorId: member.id,
    );
    await service.addNote(
      leadId: acme.id,
      body: 'Left a voicemail, will follow up Thursday.',
      actorId: member.id,
    );

    await service.createLead(
      name: 'Sam Prospect',
      email: 'sam@globex.test',
      company: 'Globex',
      source: 'referral',
      actorId: admin.id,
    );
    await service.createLead(
      name: 'Public Enquiry',
      email: 'hello@example.test',
      source: 'public_form',
    );
  }

  await db.close();

  stdout
    ..writeln('✓ Seed complete.')
    ..writeln('  Admin : $adminEmail / $adminPassword')
    ..writeln('  Member: $memberEmail / $memberPassword');
}
