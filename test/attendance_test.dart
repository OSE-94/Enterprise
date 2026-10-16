import 'package:flutter_test/flutter_test.dart';
import 'package:people_pulse/models/attendance_models.dart';
import 'package:people_pulse/models/employee_account.dart';

void main() {
  group('ClockLocation', () {
    test('serializes coordinates and accuracy for the database', () {
      const location = ClockLocation(
        latitude: 51.5072,
        longitude: -0.1276,
        accuracy: 8.5,
      );

      expect(location.toMap(), {
        'latitude': 51.5072,
        'longitude': -0.1276,
        'accuracy': 8.5,
      });
    });
  });

  group('AttendanceRecord', () {
    test('parses database fields and server timestamps', () {
      final clockIn = DateTime.utc(2026, 10, 15, 8, 30);
      final record = AttendanceRecord.fromMap({
        'id': 'shift-1',
        'employee_uid': 'firebase-user-1',
        'employee_name': 'Alex Morgan',
        'employee_email': 'alex@example.com',
        'status': 'clocked_in',
        'clock_in_at': clockIn.toIso8601String(),
        'clock_in_location': {
          'latitude': 51.5072,
          'longitude': -0.1276,
          'accuracy': 8.5,
        },
        'clock_out_at': null,
        'clock_out_location': null,
        'active_break_id': null,
        'active_break_started_at': null,
      });

      expect(record.id, 'shift-1');
      expect(record.status, AttendanceStatus.clockedIn);
      expect(record.clockInAt, clockIn);
      expect(record.clockInLocation.accuracy, 8.5);
      expect(record.clockOutAt, isNull);
    });
  });

  group('EmployeeAccount', () {
    test('recognizes the administrator role', () {
      const account = EmployeeAccount(
        uid: 'admin-1',
        email: 'admin@example.com',
        displayName: 'Team Admin',
        role: UserRole.admin,
      );

      expect(account.isAdmin, isTrue);
    });

    test('does not grant admin access to employee accounts', () {
      const account = EmployeeAccount(
        uid: 'employee-1',
        email: 'employee@example.com',
        displayName: 'Team Member',
        role: UserRole.employee,
      );

      expect(account.isAdmin, isFalse);
    });
  });
}
