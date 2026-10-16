import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_models.dart';

abstract interface class AttendanceRepository {
  Stream<List<AttendanceRecord>> watchEmployeeRecords(String userId);

  Stream<List<AttendanceRecord>> watchAllRecords();

  Stream<List<BreakEntry>> watchBreaks(AttendanceRecord record);

  Future<void> clockIn(ClockLocation location);

  Future<void> clockOut(AttendanceRecord record, ClockLocation location);

  Future<void> startBreak(AttendanceRecord record);

  Future<void> endBreak(AttendanceRecord record);
}

class AttendanceService implements AttendanceRepository {
  AttendanceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Stream<List<AttendanceRecord>> watchEmployeeRecords(String userId) {
    return _client
        .from('attendance_sessions')
        .stream(primaryKey: ['id'])
        .eq('employee_uid', userId)
        .order('clock_in_at', ascending: false)
        .limit(60)
        .map(_attendanceRecords);
  }

  @override
  Stream<List<AttendanceRecord>> watchAllRecords() {
    return _client
        .from('attendance_sessions')
        .stream(primaryKey: ['id'])
        .order('clock_in_at', ascending: false)
        .limit(300)
        .map(_attendanceRecords);
  }

  @override
  Stream<List<BreakEntry>> watchBreaks(AttendanceRecord record) {
    return _client
        .from('attendance_breaks')
        .stream(primaryKey: ['id'])
        .eq('attendance_id', record.id)
        .order('started_at')
        .map((rows) => rows.map(BreakEntry.fromMap).toList());
  }

  @override
  Future<void> clockIn(ClockLocation location) async {
    await _client.rpc(
      'clock_in',
      params: {
        'p_location': location.toMap(),
      },
    );
  }

  @override
  Future<void> clockOut(
    AttendanceRecord record,
    ClockLocation location,
  ) async {
    await _client.rpc(
      'clock_out',
      params: {
        'p_attendance_id': record.id,
        'p_location': location.toMap(),
      },
    );
  }

  @override
  Future<void> startBreak(AttendanceRecord record) async {
    await _client.rpc(
      'start_break',
      params: {'p_attendance_id': record.id},
    );
  }

  @override
  Future<void> endBreak(AttendanceRecord record) async {
    await _client.rpc(
      'end_break',
      params: {'p_attendance_id': record.id},
    );
  }

  List<AttendanceRecord> _attendanceRecords(List<Map<String, dynamic>> rows) =>
      rows.map(AttendanceRecord.fromMap).toList();
}
