import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee_account.dart';
import '../services/auth_service.dart';
import '../widgets/hr_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final employee = context.watch<EmployeeAccount>();

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
                  initials: _initials(employee.displayName),
                  radius: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  employee.displayName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.isAdmin ? 'Administrator' : 'Employee',
                  style: const TextStyle(color: Color(0xFF64716B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
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
                value: employee.email,
              ),
              const Divider(height: 1, indent: 56),
              _ProfileDetail(
                icon: Icons.groups_2_outlined,
                label: 'Department',
                value: employee.isAdmin ? 'Administration' : 'Team member',
              ),
              const Divider(height: 1, indent: 56),
              _ProfileDetail(
                icon: Icons.beach_access_outlined,
                label: 'Time-off balance',
                value: 'Managed by your People team',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            subtitle: const Text('Sign out of this account on this device.'),
            onTap: () => AuthService().signOut(),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.length == 1
      ? parts.first.substring(0, 1).toUpperCase()
      : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
