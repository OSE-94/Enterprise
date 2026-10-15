import '../models/hr_models.dart';

class HrService {
  Future<Employee> fetchEmployee() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const Employee(
      name: 'Alex Morgan',
      role: 'Product Designer',
      department: 'Product',
      email: 'alex.morgan@example.com',
      leaveBalance: 18,
      avatarInitials: 'AM',
    );
  }

  Future<List<LeaveRequest>> fetchLeaveRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final today = DateTime.now();
    return [
      LeaveRequest(
        id: 'leave-1',
        type: 'Annual leave',
        startDate: DateTime(today.year, today.month, today.day + 12),
        endDate: DateTime(today.year, today.month, today.day + 14),
        status: LeaveStatus.approved,
      ),
      LeaveRequest(
        id: 'leave-2',
        type: 'Personal day',
        startDate: DateTime(today.year, today.month, today.day - 8),
        endDate: DateTime(today.year, today.month, today.day - 8),
        status: LeaveStatus.pending,
      ),
    ];
  }

  Future<List<Announcement>> fetchAnnouncements() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (endDate.isBefore(startDate)) {
      throw Exception('The end date must be on or after the start date.');
    }

    return LeaveRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      startDate: startDate,
      endDate: endDate,
      status: LeaveStatus.pending,
    );
  }
}
