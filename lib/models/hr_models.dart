enum LeaveStatus { pending, approved, declined }

class Employee {
  const Employee({
    required this.name,
    required this.role,
    required this.department,
    required this.email,
    required this.leaveBalance,
    required this.avatarInitials,
  });

  final String name;
  final String role;
  final String department;
  final String email;
  final int leaveBalance;
  final String avatarInitials;
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeUid,
    required this.employeeName,
    required this.employeeEmail,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.adminNote,
  });

  final String id;
  final String employeeUid;
  final String employeeName;
  final String employeeEmail;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveStatus status;
  final String? adminNote;

  int get days =>
      DateTime.utc(endDate.year, endDate.month, endDate.day)
          .difference(
            DateTime.utc(startDate.year, startDate.month, startDate.day),
          )
          .inDays +
      1;

  factory LeaveRequest.fromMap(Map<String, dynamic> data) {
    return LeaveRequest(
      id: data['id'] as String,
      employeeUid: data['employee_uid'] as String,
      employeeName: data['employee_name'] as String,
      employeeEmail: data['employee_email'] as String,
      type: data['leave_type'] as String,
      startDate: DateTime.parse(data['start_date'] as String),
      endDate: DateTime.parse(data['end_date'] as String),
      status: switch (data['status'] as String) {
        'pending' => LeaveStatus.pending,
        'approved' => LeaveStatus.approved,
        'declined' => LeaveStatus.declined,
        final value => throw FormatException('Unknown leave status: $value'),
      },
      adminNote: data['admin_note'] as String?,
    );
  }
}

class Announcement {
  const Announcement({
    required this.title,
    required this.body,
    required this.category,
    required this.publishedAt,
  });

  final String title;
  final String body;
  final String category;
  final DateTime publishedAt;
}
