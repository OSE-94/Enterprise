import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_account.dart';
import '../models/hr_models.dart';

class HrService {
  HrService({
    required EmployeeAccount account,
    SupabaseClient? client,
  })  : _account = account,
        _client = client ?? Supabase.instance.client;

  final EmployeeAccount _account;
  final SupabaseClient _client;

  Future<Employee> fetchEmployee() async {
    return Employee(
      name: _account.displayName,
      role: _account.isAdmin ? 'Administrator' : 'Team member',
      department: _account.isAdmin ? 'Administration' : 'Team',
      email: _account.email,
      leaveBalance: 18,
      avatarInitials: _initials(_account.displayName),
    );
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    final rows = await _client
        .from('leave_requests')
        .select()
        .order('created_at', ascending: false);
    return rows.map(LeaveRequest.fromMap).toList();
  }

  Stream<List<LeaveRequest>> watchLeaveRequests() => _client
      .from('leave_requests')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(LeaveRequest.fromMap).toList());

  Future<List<Announcement>> fetchAnnouncements() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final today = DateTime.now();
    return [
      Announcement(
        title: 'Welcome to our new team hub',
        body:
            'Find company updates, people resources and your key work details in one place.',
        category: 'Company news',
        publishedAt: DateTime(today.year, today.month, today.day - 1),
      ),
      Announcement(
        title: 'Wellbeing afternoon',
        body:
            'Take a little time for yourself this Friday. Our offices will close at 2 pm.',
        category: 'People & culture',
        publishedAt: DateTime(today.year, today.month, today.day - 3),
      ),
      Announcement(
        title: 'Update your emergency contact',
        body:
            'Please check that your emergency contact details are current in your profile.',
        category: 'Reminder',
        publishedAt: DateTime(today.year, today.month, today.day - 5),
      ),
    ];
  }

  Future<LeaveRequest> submitLeaveRequest({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('The end date must be on or after the start date.');
    }
    final response = await _client.rpc(
      'submit_leave_request',
      params: {
        'p_leave_type': type,
        'p_start_date': _formatDate(startDate),
        'p_end_date': _formatDate(endDate),
      },
    );
    final id = response as String;
    return LeaveRequest(
      id: id,
      employeeUid: _account.uid,
      employeeName: _account.displayName,
      employeeEmail: _account.email,
      type: type,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      status: LeaveStatus.pending,
    );
  }

  Future<void> reviewLeaveRequest({
    required String requestId,
    required LeaveStatus status,
    String? adminNote,
  }) async {
    if (status == LeaveStatus.pending) {
      throw ArgumentError('A review must approve or decline the request.');
    }
    await _client.rpc(
      'review_leave_request',
      params: {
        'p_request_id': requestId,
        'p_status': status.name,
        'p_admin_note': adminNote?.trim(),
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

String _formatDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
