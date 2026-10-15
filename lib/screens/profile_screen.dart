import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hr_provider.dart';
import '../widgets/hr_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final employee = hr.employee;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const Text(
          'My profile',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                InitialsAvatar(
                  initials: employee?.avatarInitials ?? 'AM',
                  radius: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  employee?.name ?? 'Loading profile',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee?.role ?? '',
                  style: const TextStyle(color: Color(0xFF64716B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (employee == null && hr.errorMessage != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                hr.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        const Text(
          'Work details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _ProfileDetail(
                icon: Icons.alternate_email_rounded,
                label: 'Work email',
                value: employee?.email ?? '-',
              ),
              const Divider(height: 1, indent: 56),
              _ProfileDetail(
                icon: Icons.groups_2_outlined,
                label: 'Department',
                value: employee?.department ?? '-',
              ),
              const Divider(height: 1, indent: 56),
              _ProfileDetail(
                icon: Icons.beach_access_outlined,
                label: 'Time-off balance',
                value: '${employee?.leaveBalance ?? 0} days',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.help_outline_rounded),
            title: Text('Need help?'),
            subtitle: Text('Contact your People team for support.'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),
        ),
      ],
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3B6F64)),
      title: Text(
        label,
        style: const TextStyle(color: Color(0xFF64716B), fontSize: 12),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF24312C),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
