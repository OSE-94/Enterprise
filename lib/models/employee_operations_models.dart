class EmployeeMessage {
  const EmployeeMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.body,
    required this.isBroadcast,
    required this.createdAt,
    this.recipientUid,
    this.recipientName,
    this.subject = '',
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final String? recipientUid;
  final String? recipientName;
  final String subject;
  final String body;
  final bool isBroadcast;
  final DateTime createdAt;

  factory EmployeeMessage.fromMap(Map<String, dynamic> data) {
    return EmployeeMessage(
      id: data['id'] as String,
      senderUid: data['sender_uid'] as String,
      senderName: data['sender_name'] as String,
      senderEmail: data['sender_email'] as String,
      recipientUid: data['recipient_uid'] as String?,
      recipientName: data['recipient_name'] as String?,
      subject: data['subject'] as String? ?? '',
      body: data['body'] as String,
      isBroadcast: data['is_broadcast'] as bool,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

class EmployeeDirectoryEntry {
  const EmployeeDirectoryEntry({
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;

  factory EmployeeDirectoryEntry.fromMap(Map<String, dynamic> data) =>
      EmployeeDirectoryEntry(
        uid: data['uid'] as String,
        name: data['display_name'] as String,
        email: data['email'] as String,
      );
}

class AttendanceHistoryEntry {
  const AttendanceHistoryEntry({
    required this.id,
    required this.employeeUid,
    required this.employeeName,
    required this.employeeEmail,
    required this.status,
    required this.clockInAt,
    required this.workedSeconds,
    this.clockOutAt,
  });

  final String id;
  final String employeeUid;
  final String employeeName;
  final String employeeEmail;
  final String status;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final int workedSeconds;

  factory AttendanceHistoryEntry.fromMap(Map<String, dynamic> data) =>
      AttendanceHistoryEntry(
        id: data['attendance_id'] as String,
        employeeUid: data['employee_uid'] as String,
        employeeName: data['employee_name'] as String,
        employeeEmail: data['employee_email'] as String,
        status: data['status'] as String,
        clockInAt: DateTime.parse(data['clock_in_at'] as String),
        clockOutAt: data['clock_out_at'] == null
            ? null
            : DateTime.parse(data['clock_out_at'] as String),
        workedSeconds: (data['total_work_seconds'] as num).toInt(),
      );
}

class EmployeeCompensation {
  const EmployeeCompensation({
    required this.employeeUid,
    required this.hourlyRate,
    required this.currency,
  });

  final String employeeUid;
  final double hourlyRate;
  final String currency;

  factory EmployeeCompensation.fromMap(Map<String, dynamic> data) =>
      EmployeeCompensation(
        employeeUid: data['employee_uid'] as String,
        hourlyRate: (data['hourly_rate'] as num).toDouble(),
        currency: (data['currency'] as String).trim(),
      );
}
