import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attendance_models.dart';
import '../models/employee_account.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({
    required EmployeeAccount employee,
    required AttendanceRepository attendance,
    required LocationService location,
  })  : _employee = employee,
        _attendance = attendance,
        _location = location;

  final EmployeeAccount _employee;
  final AttendanceRepository _attendance;
  final LocationService _location;

  StreamSubscription<List<AttendanceRecord>>? _employeeSubscription;
  StreamSubscription<List<AttendanceRecord>>? _teamSubscription;

  List<AttendanceRecord> employeeRecords = [];
  List<AttendanceRecord> teamRecords = [];
  bool isLoading = true;
  bool isWorking = false;
  String? errorMessage;

  AttendanceRecord? get activeRecord {
    for (final record in employeeRecords) {
      if (record.status != AttendanceStatus.clockedOut) return record;
    }
    return null;
  }

  Stream<List<BreakEntry>> watchBreaks(AttendanceRecord record) =>
      _attendance.watchBreaks(record);

  void start() {
    _employeeSubscription =
        _attendance.watchEmployeeRecords(_employee.uid).listen(
      (records) {
        employeeRecords = records;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        isLoading = false;
        errorMessage = 'Could not load your attendance records: $error';
        notifyListeners();
      },
    );

    if (_employee.isAdmin) {
      _teamSubscription = _attendance.watchAllRecords().listen(
        (records) {
          teamRecords = records;
          errorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          errorMessage = 'Could not load team attendance: $error';
          notifyListeners();
        },
      );
    }
  }

  Future<bool> clockIn() async {
    return _perform(() async {
      final location = await _location.currentLocation();
      await _attendance.clockIn(location);
    });
  }

  Future<bool> clockOut() async {
    final record = activeRecord;
    if (record == null) {
      errorMessage = 'You are not currently clocked in.';
      notifyListeners();
      return false;
    }

    return _perform(() async {
      final location = await _location.currentLocation();
      await _attendance.clockOut(record, location);
    });
  }

  Future<bool> startBreak() async {
    final record = activeRecord;
    if (record == null) {
      errorMessage = 'Clock in before starting a break.';
      notifyListeners();
      return false;
    }
    return _perform(() => _attendance.startBreak(record));
  }

  Future<bool> endBreak() async {
    final record = activeRecord;
    if (record == null) {
      errorMessage = 'There is no active break to end.';
      notifyListeners();
      return false;
    }
    return _perform(() => _attendance.endBreak(record));
  }

  Future<bool> _perform(Future<void> Function() action) async {
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on Exception catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _employeeSubscription?.cancel();
    _teamSubscription?.cancel();
    super.dispose();
  }
}
