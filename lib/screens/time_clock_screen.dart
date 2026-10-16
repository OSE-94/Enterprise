import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/hr_widgets.dart';

class TimeClockScreen extends StatelessWidget {
  const TimeClockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final active = attendance.activeRecord;
    final onBreak = active?.status == AttendanceStatus.onBreak;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Time clock',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Clock events include the date, time, and your device location.',
          style: TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 20),
        _CurrentShiftCard(record: active),
        const SizedBox(height: 14),
        if (attendance.errorMessage != null) ...[
          _ErrorCard(message: attendance.errorMessage!),
          const SizedBox(height: 14),
        ],
        if (active == null)
          FilledButton.icon(
            onPressed: attendance.isWorking
                ? null
                : () => _perform(
                      context,
                      attendance.clockIn,
                      'You are clocked in.',
                    ),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Clock in'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: attendance.isWorking
                      ? null
                      : () => _perform(
                            context,
                            onBreak
                                ? attendance.endBreak
                                : attendance.startBreak,
                            onBreak ? 'Break ended.' : 'Break started.',
                          ),
                  icon: Icon(
                    onBreak ? Icons.play_arrow_rounded : Icons.coffee_rounded,
                  ),
                  label: Text(onBreak ? 'End break' : 'Start break'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: attendance.isWorking || onBreak
                      ? null
                      : () => _perform(
                            context,
                            attendance.clockOut,
                            'You are clocked out.',
                          ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Clock out'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
          if (onBreak) ...[
            const SizedBox(height: 8),
            const Text(
              'End your break before clocking out.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64716B), fontSize: 13),
            ),
          ],
        ],
        if (attendance.isWorking) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text(
            'Getting your location and saving this event…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64716B), fontSize: 13),
          ),
        ],
        const SizedBox(height: 28),
        const SectionHeading('Recent shifts'),
        const SizedBox(height: 10),
        if (attendance.isLoading && attendance.employeeRecords.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (attendance.employeeRecords.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Your clock events will appear here.'),
            ),
          )
        else
          ...attendance.employeeRecords.map(
            (record) => _AttendanceCard(record: record),
          ),
      ],
    );
  }

  Future<void> _perform(
    BuildContext context,
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final succeeded = await action();
    if (!context.mounted) return;
    if (succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  }
}

class _CurrentShiftCard extends StatelessWidget {
  const _CurrentShiftCard({required this.record});

  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final status = switch (record?.status) {
      AttendanceStatus.clockedIn => 'Clocked in',
      AttendanceStatus.onBreak => 'On break',
      AttendanceStatus.clockedOut => 'Clocked out',
      null => 'Not clocked in',
    };
    final color = switch (record?.status) {
      AttendanceStatus.clockedIn => const Color(0xFF32745B),
      AttendanceStatus.onBreak => const Color(0xFF9A6815),
      AttendanceStatus.clockedOut || null => const Color(0xFF64716B),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current status',
                    style: TextStyle(color: Color(0xFF64716B), fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (record?.clockInAt != null)
                    Text(
                      'Started ${_formatTime(record!.clockInAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF64716B),
                        fontSize: 13,
                      ),
                    ),
                  if (record?.activeBreakStartedAt != null)
                    Text(
                      'Break started ${_formatTime(record!.activeBreakStartedAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF64716B),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            StatusPill(label: status, color: color),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final status = switch (record.status) {
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.clockInAt == null
                        ? 'Saving clock-in time…'
                        : DateFormat('EEE, d MMM yyyy')
                            .format(record.clockInAt!.toLocal()),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusPill(label: status, color: color),
              ],
            ),
            const SizedBox(height: 12),
            _EventLine(
              icon: Icons.login_rounded,
              title: 'Clock in',
              date: record.clockInAt,
              location: record.clockInLocation,
            ),
            const SizedBox(height: 8),
            _EventLine(
              icon: Icons.logout_rounded,
              title: 'Clock out',
              date: record.clockOutAt,
              location: record.clockOutLocation,
            ),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _BreakHistoryDialog(record: record),
              ),
              icon: const Icon(Icons.coffee_outlined, size: 18),
              label: const Text('View break history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({
    required this.icon,
    required this.title,
    required this.date,
    required this.location,
  });

  final IconData icon;
  final String title;
  final DateTime? date;
  final ClockLocation? location;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF3B6F64)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date == null
                    ? '$title · not yet recorded'
                    : '$title · ${_formatTime(date!)}',
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

class _BreakHistoryDialog extends StatelessWidget {
  const _BreakHistoryDialog({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final attendance = context.read<AttendanceProvider>();

    return AlertDialog(
      title: const Text('Break history'),
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
            return ListView.separated(
              shrinkWrap: true,
              itemCount: breaks.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final entry = breaks[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.coffee_outlined),
                  title: Text(
                    entry.startedAt == null
                        ? 'Saving break time…'
                        : _formatTime(entry.startedAt!),
                  ),
                  subtitle: Text(
                    entry.endedAt == null
                        ? 'In progress'
                        : 'Ended ${_formatTime(entry.endedAt!)}',
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) =>
    DateFormat('d MMM yyyy, HH:mm').format(value.toLocal());
