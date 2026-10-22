import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/hr_models.dart';
import '../models/employee_account.dart';
import '../providers/hr_provider.dart';
import '../widgets/hr_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final account = context.watch<EmployeeAccount>();
    final employee = hr.employee;

    if (hr.isLoading && employee == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hr.errorMessage != null && employee == null) {
      return _LoadError(message: hr.errorMessage!, onRetry: hr.load);
    }

    final upcomingLeave = hr.leaveRequests
        .where((request) =>
            request.status == LeaveStatus.approved &&
            !request.startDate.isBefore(DateUtils.dateOnly(DateTime.now())))
        .toList();

    return RefreshIndicator(
      onRefresh: hr.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PeoplePulse',
                  style: TextStyle(
                    color: Color(0xFF315B50),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              InitialsAvatar(initials: _initials(account.displayName)),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Good ${_greeting()},',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64716B),
                ),
          ),
          const SizedBox(height: 3),
          Text(
            account.displayName.split(' ').first,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
          ),
          const SizedBox(height: 22),
          _LeaveBalanceCard(days: employee?.leaveBalance ?? 0),
          const SizedBox(height: 28),
          const SectionHeading('Quick actions'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.beach_access_rounded,
                  label: 'Request time off',
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.person_search_rounded,
                  label: 'View my profile',
                  onTap: () => onNavigate(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeading(
            'Upcoming time off',
            action: TextButton(
              onPressed: () => onNavigate(2),
              child: const Text('See all'),
            ),
          ),
          const SizedBox(height: 10),
          if (upcomingLeave.isEmpty)
            const _EmptyCard(
              icon: Icons.event_available_outlined,
              message: 'No upcoming time off. Your calendar is clear.',
            )
          else
            ...upcomingLeave.take(2).map(
                  (request) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF2EE),
                        child: Icon(
                          Icons.event_outlined,
                          color: Color(0xFF3B6F64),
                        ),
                      ),
                      title: Text(request.type),
                      subtitle: Text(
                        '${DateFormat('d MMM').format(request.startDate)} – '
                        '${DateFormat('d MMM yyyy').format(request.endDate)}',
                      ),
                      trailing: Text(
                        '${request.days} ${request.days == 1 ? 'day' : 'days'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const SectionHeading('The latest'),
          const SizedBox(height: 10),
          if (hr.announcements.isEmpty)
            const _EmptyCard(
              icon: Icons.campaign_outlined,
              message: 'There are no updates right now.',
            )
          else
            Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF1DC),
                  child: Icon(Icons.waving_hand_rounded, color: Colors.orange),
                ),
                title: Text(
                  hr.announcements.first.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  hr.announcements.first.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onNavigate(3),
              ),
            ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF315B50),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your time-off balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  '$days days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Take time to recharge',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.wb_sunny_outlined,
            color: Color(0xFFFFD990),
            size: 44,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF3B6F64)),
              const SizedBox(height: 15),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3B6F64)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
