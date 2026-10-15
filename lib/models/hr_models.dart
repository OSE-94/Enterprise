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
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveStatus status;

  int get days =>
      DateTime.utc(endDate.year, endDate.month, endDate.day)
          .difference(
            DateTime.utc(startDate.year, startDate.month, startDate.day),
          )
          .inDays +
      1;
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
