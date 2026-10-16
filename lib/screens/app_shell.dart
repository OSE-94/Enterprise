import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee_account.dart';
import 'home_screen.dart';
import 'leave_screen.dart';
import 'profile_screen.dart';
import 'team_attendance_screen.dart';
import 'time_clock_screen.dart';
import 'updates_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _setSelectedIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<EmployeeAccount>().isAdmin;
    final screens = [
      HomeScreen(onNavigate: _setSelectedIndex),
      const TimeClockScreen(),
      const LeaveScreen(),
      const UpdatesScreen(),
      const ProfileScreen(),
      if (isAdmin) const TeamAttendanceScreen(),
    ];
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.access_time_outlined),
        selectedIcon: Icon(Icons.access_time_filled_rounded),
        label: 'Clock',
      ),
      const NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        selectedIcon: Icon(Icons.event_note_rounded),
        label: 'Time off',
      ),
      const NavigationDestination(
        icon: Icon(Icons.campaign_outlined),
        selectedIcon: Icon(Icons.campaign_rounded),
        label: 'Updates',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
      if (isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups_rounded),
          label: 'Team',
        ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _setSelectedIndex,
        destinations: destinations,
      ),
    );
  }
}
