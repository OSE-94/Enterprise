import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_operations_models.dart';

class EmployeeOperationsService {
  EmployeeOperationsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<EmployeeMessage>> fetchMessages() async {
    final rows = await _client
        .from('employee_messages')
        .select()
        .order('created_at', ascending: false)
        .limit(300);
    return rows.map(EmployeeMessage.fromMap).toList();
  }

  Stream<List<EmployeeMessage>> watchMessages() => _client
      .from('employee_messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(300)
      .map((rows) => rows.map(EmployeeMessage.fromMap).toList());

  Future<List<EmployeeDirectoryEntry>> fetchEmployees() async {
    final rows = await _client
        .from('employee_profiles')
        .select('uid, display_name, email')
        .eq('role', 'employee')
        .order('display_name');
    return rows.map(EmployeeDirectoryEntry.fromMap).toList();
  }

  Future<void> sendMessage({
    required String body,
    String subject = '',
    String? recipientUid,
    bool broadcast = false,
  }) async {
    await _client.rpc(
      'send_employee_message',
      params: {
        'p_body': body,
        'p_subject': subject,
        'p_recipient_uid': recipientUid,
        'p_is_broadcast': broadcast,
      },
    );
  }

  Future<List<AttendanceHistoryEntry>> fetchHistory({
    String? employeeUid,
  }) async {
    final rows = await _client.rpc(
      'get_attendance_history',
      params: {'p_employee_uid': employeeUid},
    );
    return (rows as List)
        .map(
          (row) => AttendanceHistoryEntry.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<EmployeeCompensation>> fetchCompensation() async {
    final rows = await _client.from('employee_compensation').select();
    return rows.map(EmployeeCompensation.fromMap).toList();
  }

  Future<void> setHourlyRate({
    required String employeeUid,
    required double hourlyRate,
  }) async {
    await _client.rpc(
      'set_employee_hourly_rate',
      params: {
        'p_employee_uid': employeeUid,
        'p_hourly_rate': hourlyRate,
      },
    );
  }
}
