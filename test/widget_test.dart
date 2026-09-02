import 'package:flutter_test/flutter_test.dart';

import 'package:appointment_app/utils/dashboard_utils.dart';

void main() {
  test('normalizes nested dashboard payloads', () {
    final payload = {
      'data': {
        'summary': {
          'upcoming': 4,
          'held': 2,
          'missed': 1,
          'action_points_pending': 3,
          'next_appointment': {'id': 29, 'purpose': 'Client check-in'},
          'recent_held_appointments': [
            {'id': 10, 'purpose': 'Follow up', 'appointment_date': '2026-09-01'}
          ],
          'recent_activity': [
            {'title': 'Discussed roadmap', 'status': 'held'}
          ],
          'action_points': [
            {'description': 'Send proposal', 'due_date': '2026-09-05'}
          ],
        }
      }
    };

    final normalized = normalizeDashboardPayload(payload);

    expect(normalized['upcoming'], 4);
    expect(normalized['held'], 2);
    expect(normalized['missed'], 1);
    expect(normalized['action_points_pending'], 3);
    expect((normalized['recent_held_appointments'] as List).length, 1);
    expect((normalized['recent_activity'] as List).length, 1);
    expect((normalized['action_points'] as List).length, 1);
    expect((normalized['next_appointment'] as Map)['id'], 29);
  });
}
