import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class AttendanceShiftDetails extends StatefulWidget {
  const AttendanceShiftDetails({
    required this.record,
    super.key,
  });

  final AttendanceRecord record;

  @override
  State<AttendanceShiftDetails> createState() => _AttendanceShiftDetailsState();
}

class _AttendanceShiftDetailsState extends State<AttendanceShiftDetails> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  late Stream<List<BreakEntry>> _breaksStream;

  bool get _isActive => widget.record.clockOutAt == null;

  @override
  void initState() {
    super.initState();
    _breaksStream =
        context.read<AttendanceProvider>().watchBreaks(widget.record);
    _startTimerIfActive();
  }

  @override
  void didUpdateWidget(covariant AttendanceShiftDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _breaksStream =
          context.read<AttendanceProvider>().watchBreaks(widget.record);
    }
    if (oldWidget.record.clockOutAt != widget.record.clockOutAt) {
      _timer?.cancel();
      _startTimerIfActive();
    }
  }

  void _startTimerIfActive() {
    if (!_isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final start = record.clockInAt;
    if (start == null) {
      return const Text('Shift duration is not available yet.');
    }
    final end = record.clockOutAt ?? _now;
    final elapsed = record.elapsedDuration(now: _now);

    return StreamBuilder<List<BreakEntry>>(
      stream: _breaksStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load break time: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        final breaks = snapshot.data!;
        final breakDuration = record.totalBreakDuration(breaks, now: _now);
        final workedDuration = record.workedDuration(breaks, now: _now);
        final timeFormat = DateFormat('d MMM, HH:mm');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            _LocationRow(
              label: 'Clock-in location',
              time: start,
              location: record.clockInLocation,
            ),
            const SizedBox(height: 8),
            _LocationRow(
              label: 'Clock-out location',
              time: record.clockOutAt,
              location: record.clockOutLocation,
            ),
            const SizedBox(height: 12),
            Text(
              'Time calculation',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${record.clockOutAt == null ? 'Now' : timeFormat.format(end.toLocal())}'
              ' − ${timeFormat.format(start.toLocal())}'
              ' = ${_formatDuration(elapsed)} elapsed',
            ),
            Text(
              '${_formatDuration(elapsed)} elapsed'
              ' − ${_formatDuration(breakDuration)} breaks'
              ' = ${_formatDuration(workedDuration)} worked',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total time worked: ${_formatDuration(workedDuration)}'
              '${record.clockOutAt == null ? ' (so far)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.time,
    required this.location,
  });

  final String label;
  final DateTime? time;
  final ClockLocation? location;

  @override
  Widget build(BuildContext context) {
    final location = this.location;
    final time = this.time;
    if (time == null) {
      return Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18),
          const SizedBox(width: 8),
          Text('$label: not recorded yet'),
        ],
      );
    }
    if (location == null) {
      return Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: location unavailable')),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · ${DateFormat('d MMM, HH:mm').format(time.toLocal())}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${location.latitude.toStringAsFixed(5)}, '
                '${location.longitude.toStringAsFixed(5)} '
                '(±${location.accuracy.round()} m)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _openMap(context, location),
          child: const Text('Map'),
        ),
      ],
    );
  }

  Future<void> _openMap(BuildContext context, ClockLocation location) async {
    final query = '${location.latitude},${location.longitude}';
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map.')),
      );
    }
  }
}

String _formatDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}
