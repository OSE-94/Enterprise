import 'package:flutter_test/flutter_test.dart';
import 'package:people_pulse/models/attendance_models.dart';
import 'package:people_pulse/models/employee_operations_models.dart';
import 'package:people_pulse/models/employee_account.dart';
import 'package:people_pulse/models/hr_models.dart';

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

  group('LeaveRequest', () {
    test('parses a persistent pending request returned by Supabase', () {
      final request = LeaveRequest.fromMap({
        'id': 'leave-1',
        'employee_uid': 'employee-1',
        'employee_name': 'Alex Morgan',
        'employee_email': 'alex@example.com',
        'leave_type': 'Annual leave',
        'start_date': '2026-11-02',
        'end_date': '2026-11-04',
        'status': 'pending',
        'admin_note': null,
      });

      expect(request.status, LeaveStatus.pending);
      expect(request.days, 3);
      expect(request.employeeUid, 'employee-1');
    });
  });

  group('Employee operations models', () {
    test('parses messages and computed attendance history', () {
      final message = EmployeeMessage.fromMap({
        'id': 'message-1',
        'sender_uid': 'admin-1',
        'sender_name': 'Team Admin',
        'sender_email': 'admin@example.com',
        'recipient_uid': null,
        'recipient_name': null,
        'subject': 'Update',
        'body': 'Team meeting at 10.',
        'is_broadcast': true,
        'created_at': '2026-10-22T09:00:00Z',
      });
      final history = AttendanceHistoryEntry.fromMap({
        'attendance_id': 'shift-1',
        'employee_uid': 'employee-1',
        'employee_name': 'Alex Morgan',
        'employee_email': 'alex@example.com',
        'status': 'clocked_out',
        'clock_in_at': '2026-10-21T08:00:00Z',
        'clock_out_at': '2026-10-21T16:30:00Z',
        'total_work_seconds': 27000,
      });

      expect(message.isBroadcast, isTrue);
      expect(history.workedSeconds, 27000);
      expect(history.clockOutAt, isNotNull);
    });
  });
}
