import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/hr_widgets.dart';

class TeamAttendanceScreen extends StatelessWidget {
  const TeamAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Team attendance',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Clock events shared by employees in your workspace.',
          style: TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 20),
        if (attendance.errorMessage != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                attendance.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        if (attendance.teamRecords.isEmpty && attendance.isLoading)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (attendance.teamRecords.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No attendance records have been submitted yet.'),
            ),
          )
        else ...[
          _SummaryCard(records: attendance.teamRecords),
          const SizedBox(height: 14),
          ...attendance.teamRecords.map(
            (record) => _TeamRecordCard(record: record),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final activeCount = records
        .where((record) => record.status != AttendanceStatus.clockedOut)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.groups_rounded, color: Color(0xFF3B6F64)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$activeCount currently clocked in',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${records.length} recent'),
          ],
        ),
      ),
    );
  }
}

class _TeamRecordCard extends StatelessWidget {
  const _TeamRecordCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final label = switch (record.status) {
      AttendanceStatus.clockedIn => 'Clocked in',
      AttendanceStatus.onBreak => 'On break',
      AttendanceStatus.clockedOut => 'Complete',
    };
    final color = switch (record.status) {
      AttendanceStatus.clockedIn => const Color(0xFF32745B),
      AttendanceStatus.onBreak => const Color(0xFF9A6815),
      AttendanceStatus.clockedOut => const Color(0xFF64716B),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: InitialsAvatar(
              initials: _initials(record.employeeName),
              radius: 22,
            ),
            title: Text(
              record.employeeName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(record.employeeEmail),
            trailing: StatusPill(label: label, color: color),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TeamEvent(
                  label: 'Clock in',
                  date: record.clockInAt,
                  location: record.clockInLocation,
                ),
                const SizedBox(height: 8),
                _TeamEvent(
                  label: 'Clock out',
                  date: record.clockOutAt,
                  location: record.clockOutLocation,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => _AdminBreakHistoryDialog(record: record),
                    ),
                    icon: const Icon(Icons.coffee_outlined, size: 18),
                    label: const Text('View breaks'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _TeamEvent extends StatelessWidget {
  const _TeamEvent({
    required this.label,
    required this.date,
    required this.location,
  });

  final String label;
  final DateTime? date;
  final ClockLocation? location;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 18,
          color: Color(0xFF3B6F64),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ${date == null ? '—' : _dateTime(date!)}',
                style: const TextStyle(fontSize: 13),
              ),
              if (location != null)
                Text(
                  '${location!.latitude.toStringAsFixed(5)}, '
                  '${location!.longitude.toStringAsFixed(5)} '
                  '(±${location!.accuracy.round()} m)',
                  style: const TextStyle(
                    color: Color(0xFF64716B),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminBreakHistoryDialog extends StatelessWidget {
  const _AdminBreakHistoryDialog({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final attendance = context.read<AttendanceProvider>();

    return AlertDialog(
      title: Text('${record.employeeName} · breaks'),
      content: SizedBox(
        width: 360,
        child: StreamBuilder<List<BreakEntry>>(
          stream: attendance.watchBreaks(record),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Could not load breaks: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final breaks = snapshot.data!;
            if (breaks.isEmpty) return const Text('No breaks recorded.');
            return ListView.builder(
              shrinkWrap: true,
              itemCount: breaks.length,
              itemBuilder: (context, index) {
                final entry = breaks[index];
                return ListTile(
                  leading: const Icon(Icons.coffee_outlined),
                  title: Text(
                    entry.startedAt == null
                        ? 'Saving break time…'
                        : _dateTime(entry.startedAt!),
                  ),
                  subtitle: Text(
                    entry.endedAt == null
                        ? 'In progress'
                        : 'Ended ${_dateTime(entry.endedAt!)}',
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

String _dateTime(DateTime value) =>
    '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year} '
    '${value.toLocal().hour.toString().padLeft(2, '0')}:'
    '${value.toLocal().minute.toString().padLeft(2, '0')}';
