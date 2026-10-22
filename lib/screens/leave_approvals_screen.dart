import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/hr_models.dart';
import '../providers/hr_provider.dart';
import '../widgets/hr_widgets.dart';

class LeaveApprovalsScreen extends StatelessWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final requests = [...hr.leaveRequests]..sort((a, b) {
        if (a.status == LeaveStatus.pending &&
            b.status != LeaveStatus.pending) {
          return -1;
        }
        if (b.status == LeaveStatus.pending &&
            a.status != LeaveStatus.pending) {
          return 1;
        }
        return b.startDate.compareTo(a.startDate);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'Time-off approvals',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review and respond to employee leave requests.',
          style: TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Refresh requests',
            onPressed: hr.isSubmittingLeave ? null : hr.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        if (hr.errorMessage != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(hr.errorMessage!),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (hr.isLoading && requests.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (requests.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('There are no leave requests yet.'),
            ),
          )
        else
          ...requests.map(
            (request) => _ApprovalCard(
              request: request,
              isWorking: hr.isSubmittingLeave,
            ),
          ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    required this.isWorking,
  });

  final LeaveRequest request;
  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    final status = switch (request.status) {
      LeaveStatus.pending => ('Pending', const Color(0xFF9A6815)),
      LeaveStatus.approved => ('Approved', const Color(0xFF32745B)),
      LeaveStatus.declined => ('Declined', const Color(0xFFB54747)),
    };
    final dateFormat = DateFormat('d MMM yyyy');
    final dates = request.startDate == request.endDate
        ? dateFormat.format(request.startDate)
        : '${dateFormat.format(request.startDate)} – '
            '${dateFormat.format(request.endDate)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.employeeName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusPill(label: status.$1, color: status.$2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              request.employeeEmail,
              style: const TextStyle(color: Color(0xFF64716B)),
            ),
            const Divider(height: 22),
            Text(
              request.type,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('$dates · ${request.days} '
                '${request.days == 1 ? 'day' : 'days'}'),
            if (request.adminNote?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Admin note: ${request.adminNote}'),
            ],
            if (request.status == LeaveStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isWorking
                          ? null
                          : () => _review(
                                context,
                                LeaveStatus.declined,
                              ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isWorking
                          ? null
                          : () => _review(
                                context,
                                LeaveStatus.approved,
                              ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, LeaveStatus status) async {
    final provider = context.read<HrProvider>();
    final succeeded = await provider.reviewLeaveRequest(
      request: request,
      status: status,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'Request ${status.name}.'
              : provider.errorMessage ?? 'Could not review the request.',
        ),
      ),
    );
  }
}
