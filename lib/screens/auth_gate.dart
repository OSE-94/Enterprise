import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/employee_account.dart';
import '../providers/attendance_provider.dart';
import '../providers/hr_provider.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/hr_service.dart';
import '../services/location_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AuthError(
              message: 'Authentication failed: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          _auth.requestedLoginRole = null;
          return LoginScreen(auth: _auth);
        }
        return _ProfileLoader(
          key: ValueKey(user.uid),
          auth: _auth,
          user: user,
          requestedRole: _auth.requestedLoginRole,
        );
      },
    );
  }
}

class _ProfileLoader extends StatefulWidget {
  const _ProfileLoader({
    required this.auth,
    required this.user,
    required this.requestedRole,
    super.key,
  });

  final AuthService auth;
  final User user;
  final UserRole? requestedRole;

  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  late final Future<EmployeeAccount> _profile =
      widget.auth.loadProfile(widget.user);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeAccount>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is PostgrestException &&
                  (error.code == '42501' || error.code == 'PGRST301')
              ? 'Supabase rejected the Firebase sign-in token. Confirm the '
                  'Firebase third-party integration is configured and this '
                  'account has the role=authenticated custom claim. '
                  'Details: $error'
              : 'Could not load your profile: $error';
          return _AuthError(
            message: message,
          );
        }
        if (!snapshot.hasData) return const _LoadingScreen();
        final employee = snapshot.data!;
        if (widget.requestedRole != null &&
            widget.requestedRole != employee.role) {
          final selectedRole =
              widget.requestedRole == UserRole.admin ? 'admin' : 'employee';
          final assignedRole =
              employee.role == UserRole.admin ? 'admin' : 'employee';
          return _AuthError(
            message: 'You selected $selectedRole sign-in, but this account is '
                'assigned the $assignedRole role. Contact your administrator '
                'if you need your access changed.',
          );
        }

        return MultiProvider(
          providers: [
            Provider<EmployeeAccount>.value(value: employee),
            ChangeNotifierProvider(
              create: (_) =>
                  HrProvider(employee, HrService(account: employee))..load(),
            ),
            ChangeNotifierProvider(
              create: (_) => AttendanceProvider(
                employee: employee,
                attendance: AttendanceService(),
                location: LocationService(),
              )..start(),
            ),
          ],
          child: const AppShell(),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
