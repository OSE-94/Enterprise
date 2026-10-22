import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/hr_widgets.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    required this.onViewLeave,
    required this.onViewMessages,
    required this.onViewHistory,
    required this.onViewAttendance,
    super.key,
  });

  final VoidCallback onViewLeave;
  final VoidCallback onViewMessages;
  final VoidCallback onViewHistory;
  final VoidCallback onViewAttendance;

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final records = attendance.teamRecords;
    final now = DateTime.now();
    final todayRecords = records.where((record) {
      final date = record.clockInAt?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final workingNow = records
        .where((record) => record.status == AttendanceStatus.clockedIn)
        .length;
    final onBreak = records
        .where((record) => record.status == AttendanceStatus.onBreak)
        .length;
    final employeesToday = todayRecords.map((record) => record.userId).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Admin dashboard',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'A live overview of your team’s attendance.',
          style: TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 20),
        if (attendance.errorMessage != null) ...[
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
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DashboardMetric(
              label: 'Working now',
              value: '$workingNow',
              icon: Icons.work_outline_rounded,
              color: const Color(0xFF32745B),
            ),
            _DashboardMetric(
              label: 'On break',
              value: '$onBreak',
              icon: Icons.coffee_outlined,
              color: const Color(0xFF9A6815),
            ),
            _DashboardMetric(
              label: 'Employees today',
              value: '${employeesToday.length}',
              icon: Icons.groups_outlined,
              color: const Color(0xFF3B6F64),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onViewLeave,
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Review leave'),
            ),
            OutlinedButton.icon(
              onPressed: onViewMessages,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Messages'),
            ),
            OutlinedButton.icon(
              onPressed: onViewHistory,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('History & pay'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        SectionHeading(
          'Recent team activity',
          action: TextButton(
            onPressed: onViewAttendance,
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: 8),
        if (attendance.isLoading && records.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (records.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Team attendance will appear here when employees '
                  'start recording shifts.'),
            ),
          )
        else ...[
          for (final record in records.take(5))
            _RecentAttendanceTile(record: record),
          if (records.length > 5)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onViewAttendance,
                child: const Text('See all team attendance'),
              ),
            ),
        ],
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64716B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAttendanceTile extends StatelessWidget {
  const _RecentAttendanceTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (record.status) {
      AttendanceStatus.clockedIn => ('Working', const Color(0xFF32745B)),
      AttendanceStatus.onBreak => ('On break', const Color(0xFF9A6815)),
      AttendanceStatus.clockedOut => ('Clocked out', const Color(0xFF64716B)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: InitialsAvatar(initials: _initials(record.employeeName)),
        title: Text(
          record.employeeName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          record.clockInAt == null
              ? 'Clock-in time unavailable'
              : 'Clocked in ${_formatTime(record.clockInAt!.toLocal())}',
        ),
        trailing: StatusPill(label: label, color: color),
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

  String _formatTime(DateTime date) => '${date.day}/${date.month}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
