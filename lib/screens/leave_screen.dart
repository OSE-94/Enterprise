import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/hr_models.dart';
import '../providers/hr_provider.dart';
import '../widgets/hr_widgets.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Time off',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Plan a break or check on a request.',
          style: TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.beach_access_rounded,
                  color: Color(0xFF3B6F64),
                  size: 26,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Available balance',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${hr.employee?.leaveBalance ?? 0} days',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _LeaveRequestDialog(),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Request time off'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
        const SizedBox(height: 28),
        if (hr.errorMessage != null) ...[
          _ErrorNotice(message: hr.errorMessage!),
          const SizedBox(height: 14),
        ],
        const SectionHeading('Your requests'),
        const SizedBox(height: 10),
        if (hr.isLoading && hr.leaveRequests.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hr.leaveRequests.isEmpty && hr.errorMessage == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('You have not made any time-off requests yet.'),
            ),
          )
        else
          ...hr.leaveRequests.map((request) => _LeaveRequestCard(request)),
      ],
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

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

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard(this.request);

  final LeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (request.status) {
      LeaveStatus.pending => ('Pending', const Color(0xFF9A6815)),
      LeaveStatus.approved => ('Approved', const Color(0xFF32745B)),
      LeaveStatus.declined => ('Declined', const Color(0xFFB54747)),
    };
    final dateFormat = DateFormat('d MMM yyyy');
    final dateLabel = request.startDate == request.endDate
        ? dateFormat.format(request.startDate)
        : '${dateFormat.format(request.startDate)} – '
            '${dateFormat.format(request.endDate)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEAF2EE),
              child: Icon(Icons.event_outlined, color: Color(0xFF3B6F64)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateLabel · ${request.days} '
                    '${request.days == 1 ? 'day' : 'days'}',
                    style: const TextStyle(
                      color: Color(0xFF64716B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(label: label, color: color),
          ],
        ),
      ),
    );
  }
}

class _LeaveRequestDialog extends StatefulWidget {
  const _LeaveRequestDialog();

  @override
  State<_LeaveRequestDialog> createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends State<_LeaveRequestDialog> {
  static const _leaveTypes = [
    'Annual leave',
    'Personal day',
    'Medical leave',
  ];

  String _type = _leaveTypes.first;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    _endDate = _startDate;
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();

    return AlertDialog(
      title: const Text('Request time off'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: _leaveTypes
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 14),
            _DateField(
              label: 'First day',
              date: _startDate,
              onPressed: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: 10),
            _DateField(
              label: 'Last day',
              date: _endDate,
              onPressed: () => _pickDate(isStart: false),
            ),
            if (hr.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                hr.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: hr.isSubmittingLeave
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: hr.isSubmittingLeave ? null : _submit,
          child: hr.isSubmittingLeave
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send request'),
        ),
      ],
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: isStart ? today : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final success = await context.read<HrProvider>().submitLeaveRequest(
          type: _type,
          startDate: _startDate,
          endDate: _endDate,
        );
    if (!mounted || !success) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your time-off request has been sent.')),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64716B)),
            ),
          ),
          Text(
            DateFormat('d MMM yyyy').format(date),
            style: const TextStyle(
              color: Color(0xFF24312C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
