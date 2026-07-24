import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/models.dart';

void main() {
  group('Lead.fromJson', () {
    test('parses all fields including status and timestamps', () {
      final lead = Lead.fromJson({
        'id': 'lead-1',
        'name': 'Jane Buyer',
        'email': 'jane@acme.test',
        'phone': null,
        'company': 'Acme',
        'source': 'website',
        'status': 'contacted',
        'assignedTo': 'user-9',
        'createdBy': null,
        'createdAt': '2026-07-24T10:00:00.000Z',
        'updatedAt': '2026-07-24T11:00:00.000Z',
      });

      expect(lead.id, 'lead-1');
      expect(lead.name, 'Jane Buyer');
      expect(lead.status, LeadStatus.contacted);
      expect(lead.company, 'Acme');
      expect(lead.assignedTo, 'user-9');
      expect(lead.createdBy, isNull);
      expect(lead.updatedAt.isAfter(lead.createdAt), isTrue);
    });
  });

  group('Paginated.fromJson', () {
    test('parses the data list and pagination metadata', () {
      final page = Paginated<Lead>.fromJson({
        'data': [
          {
            'id': 'l1',
            'name': 'A',
            'email': 'a@x.io',
            'status': 'new',
            'createdAt': '2026-07-24T10:00:00.000Z',
            'updatedAt': '2026-07-24T10:00:00.000Z',
          },
        ],
        'pagination': {
          'page': 2,
          'limit': 20,
          'total': 41,
          'totalPages': 3,
        },
      }, Lead.fromJson);

      expect(page.items, hasLength(1));
      expect(page.items.first.status, LeadStatus.newLead);
      expect(page.page, 2);
      expect(page.total, 41);
      expect(page.totalPages, 3);
    });
  });

  group('UserRole', () {
    test('maps role strings and admin flag', () {
      final admin = User.fromJson({
        'id': 'u1',
        'email': 'a@x.io',
        'name': 'Admin',
        'role': 'admin',
      });
      final member = User.fromJson({
        'id': 'u2',
        'email': 'm@x.io',
        'name': 'Member',
        'role': 'member',
      });
      expect(admin.isAdmin, isTrue);
      expect(member.isAdmin, isFalse);
    });
  });
}
