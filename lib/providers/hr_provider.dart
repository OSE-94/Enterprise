import 'package:flutter/foundation.dart';

import '../models/hr_models.dart';
import '../services/hr_service.dart';

class HrProvider extends ChangeNotifier {
  HrProvider(this._service);

  final HrService _service;

  Employee? employee;
  List<LeaveRequest> leaveRequests = [];
  List<Announcement> announcements = [];
  bool isLoading = false;
  bool isSubmittingLeave = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _service.fetchEmployee(),
        _service.fetchLeaveRequests(),
        _service.fetchAnnouncements(),
      ]);
      employee = results[0] as Employee;
      leaveRequests = results[1] as List<LeaveRequest>;
      announcements = results[2] as List<Announcement>;
    } on Exception catch (error) {
      errorMessage = 'We could not load your information. $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeaveRequest({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    isSubmittingLeave = true;
    errorMessage = null;
    notifyListeners();

    try {
      final request = await _service.submitLeaveRequest(
        type: type,
        startDate: startDate,
        endDate: endDate,
      );
      leaveRequests = [request, ...leaveRequests];
      return true;
    } on Exception catch (error) {
      errorMessage = 'Your leave request could not be submitted. $error';
      return false;
    } finally {
      isSubmittingLeave = false;
      notifyListeners();
    }
  }
}
