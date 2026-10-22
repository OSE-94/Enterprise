import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee_account.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'leave_screen.dart';
import 'leave_approvals_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'team_attendance_screen.dart';
import 'time_clock_screen.dart';
import 'updates_screen.dart';
import 'work_history_screen.dart';

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
    if (isAdmin) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              AdminDashboardScreen(
                onViewLeave: () => _setSelectedIndex(1),
                onViewMessages: () => _setSelectedIndex(2),
                onViewHistory: () => _setSelectedIndex(3),
                onViewAttendance: () => _setSelectedIndex(4),
              ),
              const LeaveApprovalsScreen(),
              const MessagesScreen(),
              const WorkHistoryScreen(),
              const TeamAttendanceScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _setSelectedIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Leave',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History & pay',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

    final screens = [
      HomeScreen(onNavigate: _setSelectedIndex),
      const TimeClockScreen(),
      const LeaveScreen(),
      const MessagesScreen(),
      const WorkHistoryScreen(),
      const UpdatesScreen(),
      const ProfileScreen(),
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
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum_rounded),
        label: 'Messages',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_rounded),
        selectedIcon: Icon(Icons.history_rounded),
        label: 'History',
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
