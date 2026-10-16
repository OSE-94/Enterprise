enum AttendanceStatus { clockedIn, onBreak, clockedOut }

class AttendanceActionException implements Exception {
  const AttendanceActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ClockLocation {
  const ClockLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double accuracy;

  Map<String, Object> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      };

  factory ClockLocation.fromMap(Map<String, dynamic> map) {
    return ClockLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.employeeEmail,
    required this.status,
    required this.clockInAt,
    required this.clockInLocation,
    this.clockOutAt,
    this.clockOutLocation,
    this.activeBreakId,
    this.activeBreakStartedAt,
  });

  final String id;
  final String userId;
  final String employeeName;
  final String employeeEmail;
  final AttendanceStatus status;
  final DateTime? clockInAt;
  final ClockLocation clockInLocation;
  final DateTime? clockOutAt;
  final ClockLocation? clockOutLocation;
  final String? activeBreakId;
  final DateTime? activeBreakStartedAt;

  factory AttendanceRecord.fromMap(Map<String, dynamic> data) {
    return AttendanceRecord(
      id: data['id'] as String,
      userId: data['employee_uid'] as String,
      employeeName: data['employee_name'] as String,
      employeeEmail: data['employee_email'] as String,
      status: switch (data['status'] as String) {
        'clocked_in' => AttendanceStatus.clockedIn,
        'on_break' => AttendanceStatus.onBreak,
        'clocked_out' => AttendanceStatus.clockedOut,
        final value => throw FormatException(
            'Unknown attendance status: $value',
          ),
      },
      clockInAt: _parseDate(data['clock_in_at']),
      clockInLocation: ClockLocation.fromMap(
        Map<String, dynamic>.from(data['clock_in_location'] as Map),
      ),
      clockOutAt: _parseDate(data['clock_out_at']),
      clockOutLocation: data['clock_out_location'] == null
          ? null
          : ClockLocation.fromMap(
              Map<String, dynamic>.from(data['clock_out_location'] as Map),
            ),
      activeBreakId: data['active_break_id'] as String?,
      activeBreakStartedAt: _parseDate(data['active_break_started_at']),
    );
  }
}

class BreakEntry {
  const BreakEntry({
    required this.id,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory BreakEntry.fromMap(Map<String, dynamic> data) {
    return BreakEntry(
      id: data['id'] as String,
      startedAt: _parseDate(data['started_at']),
      endedAt: _parseDate(data['ended_at']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  throw FormatException('Invalid timestamp value: $value');
}
