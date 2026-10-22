import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/employee_account.dart';
import '../models/employee_operations_models.dart';
import '../services/employee_operations_service.dart';
import '../widgets/hr_widgets.dart';

class WorkHistoryScreen extends StatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  State<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends State<WorkHistoryScreen> {
  final _service = EmployeeOperationsService();
  bool _loading = true;
  String? _error;
  List<AttendanceHistoryEntry> _history = [];
  List<EmployeeDirectoryEntry> _employees = [];
  Map<String, EmployeeCompensation> _compensation = {};
  String? _savingRateFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = context.read<EmployeeAccount>();
      if (account.isAdmin) {
        final results = await Future.wait([
          _service.fetchHistory(),
          _service.fetchEmployees(),
          _service.fetchCompensation(),
        ]);
        if (!mounted) return;
        setState(() {
          _history = results[0] as List<AttendanceHistoryEntry>;
          _employees = results[1] as List<EmployeeDirectoryEntry>;
          _compensation = {
            for (final value in results[2] as List<EmployeeCompensation>)
              value.employeeUid: value,
          };
          _loading = false;
        });
      } else {
        final history = await _service.fetchHistory(employeeUid: account.uid);
        if (!mounted) return;
        setState(() {
          _history = history;
          _loading = false;
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load work history: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<EmployeeAccount>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                account.isAdmin ? 'Team work history' : 'Work history',
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Refresh history',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          account.isAdmin
              ? 'Recorded hours and estimated pay by employee.'
              : 'Your recorded shifts and total working time.',
          style: const TextStyle(color: Color(0xFF64716B)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_error!),
            ),
          ),
        ],
        if (_loading && _history.isEmpty && _employees.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (account.isAdmin)
          ..._adminHistory()
        else
          ..._employeeHistory(),
      ],
    );
  }

  List<Widget> _employeeHistory() {
    if (_history.isEmpty) {
      return const [
        SizedBox(height: 18),
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('Your completed and active shifts will appear here.'),
          ),
        ),
      ];
    }
    final total =
        _history.fold<int>(0, (sum, entry) => sum + entry.workedSeconds);
    return [
      const SizedBox(height: 16),
      _TotalHoursCard(seconds: total),
      const SizedBox(height: 14),
      ..._history.map((entry) => _ShiftCard(entry: entry)),
    ];
  }

  List<Widget> _adminHistory() {
    if (_employees.isEmpty) {
      return const [
        SizedBox(height: 18),
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child:
                Text('Employee profiles and shift history will appear here.'),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 16),
      for (final employee in _employees)
        _EmployeeHistoryCard(
          employee: employee,
          history: _history
              .where((entry) => entry.employeeUid == employee.uid)
              .toList(),
          compensation: _compensation[employee.uid],
          isSavingRate: _savingRateFor == employee.uid,
          onSetRate: (rate) => _setRate(employee, rate),
        ),
    ];
  }

  Future<void> _setRate(
    EmployeeDirectoryEntry employee,
    double rate,
  ) async {
    setState(() {
      _savingRateFor = employee.uid;
      _error = null;
    });
    try {
      await _service.setHourlyRate(
        employeeUid: employee.uid,
        hourlyRate: rate,
      );
      await _load();
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not update hourly rate: $error';
          _savingRateFor = null;
        });
      }
    }
    if (mounted) setState(() => _savingRateFor = null);
  }
}

class _TotalHoursCard extends StatelessWidget {
  const _TotalHoursCard({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Color(0xFF3B6F64)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Total recorded working time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _duration(seconds),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeHistoryCard extends StatelessWidget {
  const _EmployeeHistoryCard({
    required this.employee,
    required this.history,
    required this.compensation,
    required this.isSavingRate,
    required this.onSetRate,
  });

  final EmployeeDirectoryEntry employee;
  final List<AttendanceHistoryEntry> history;
  final EmployeeCompensation? compensation;
  final bool isSavingRate;
  final ValueChanged<double> onSetRate;

  @override
  Widget build(BuildContext context) {
    final totalSeconds =
        history.fold<int>(0, (sum, entry) => sum + entry.workedSeconds);
    final rate = compensation?.hourlyRate;
    final payEstimate = rate == null ? null : totalSeconds / 3600 * rate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: InitialsAvatar(initials: _initials(employee.name)),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_duration(totalSeconds)} recorded'
          '${payEstimate == null ? '' : ' · £${payEstimate.toStringAsFixed(2)} estimated'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rate == null
                      ? 'Hourly rate not set'
                      : '£${rate.toStringAsFixed(2)} per hour',
                ),
              ),
              OutlinedButton(
                onPressed: isSavingRate ? null : () => _editRate(context),
                child: Text(rate == null ? 'Set rate' : 'Change rate'),
              ),
            ],
          ),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('No shifts recorded yet.'),
            )
          else
            ...history.map((entry) => _ShiftCard(entry: entry)),
        ],
      ),
    );
  }

  Future<void> _editRate(BuildContext context) async {
    final controller = TextEditingController(
      text: compensation?.hourlyRate.toStringAsFixed(2) ?? '',
    );
    String? inputError;
    final rate = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Hourly rate · ${employee.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Rate in GBP per hour',
              prefixText: '£ ',
              errorText: inputError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (inputError != null) {
                setDialogState(() => inputError = null);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value < 0 || value > 100000) {
                  setDialogState(
                    () => inputError = 'Enter a rate from £0 to £100,000.',
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Save rate'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (rate != null) onSetRate(rate);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.entry});

  final AttendanceHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final start = entry.clockInAt.toLocal();
    final end = entry.clockOutAt?.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time_rounded),
      title: Text(DateFormat('EEE d MMM yyyy').format(start)),
      subtitle: Text(
        'In ${DateFormat('HH:mm').format(start)}'
        '${end == null ? ' · Still clocked in' : ' · Out ${DateFormat('HH:mm').format(end)}'}',
      ),
      trailing: Text(
        _duration(entry.workedSeconds),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}
