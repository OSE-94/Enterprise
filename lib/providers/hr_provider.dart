import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/employee_account.dart';
import '../models/hr_models.dart';
import '../services/hr_service.dart';

class HrProvider extends ChangeNotifier {
  HrProvider(this._account, this._service);

  final EmployeeAccount _account;
  final HrService _service;
  StreamSubscription<List<LeaveRequest>>? _leaveSubscription;

  Employee? employee;
  List<LeaveRequest> leaveRequests = [];
  List<Announcement> announcements = [];
  bool isLoading = false;
  bool isSubmittingLeave = false;
  String? errorMessage;

  bool get isAdmin => _account.isAdmin;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _leaveSubscription ??= _service.watchLeaveRequests().listen(
      (requests) {
        leaveRequests = isAdmin
            ? requests
            : requests
                .where((request) => request.employeeUid == _account.uid)
                .toList();
        notifyListeners();
      },
      onError: (Object error) {
        errorMessage = 'We could not load leave requests. $error';
        notifyListeners();
      },
    );

    try {
      final results = await Future.wait<Object>([
        _service.fetchEmployee(),
        _service.fetchLeaveRequests(),
        _service.fetchAnnouncements(),
      ]);
      employee = results[0] as Employee;
      final requests = results[1] as List<LeaveRequest>;
      leaveRequests = isAdmin
          ? requests
          : requests
              .where((request) => request.employeeUid == _account.uid)
              .toList();
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

  Future<bool> reviewLeaveRequest({
    required LeaveRequest request,
    required LeaveStatus status,
  }) async {
    isSubmittingLeave = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.reviewLeaveRequest(
        requestId: request.id,
        status: status,
      );
      leaveRequests = leaveRequests
          .map((item) => item.id == request.id
              ? LeaveRequest(
                  id: item.id,
                  employeeUid: item.employeeUid,
                  employeeName: item.employeeName,
                  employeeEmail: item.employeeEmail,
                  type: item.type,
                  startDate: item.startDate,
                  endDate: item.endDate,
                  status: status,
                  adminNote: item.adminNote,
                )
              : item)
          .toList();
      return true;
    } on Exception catch (error) {
      errorMessage = 'The leave request could not be reviewed. $error';
      return false;
    } finally {
      isSubmittingLeave = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _leaveSubscription?.cancel();
    super.dispose();
  }
}
