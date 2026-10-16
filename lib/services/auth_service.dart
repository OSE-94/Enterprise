import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/employee_account.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, SupabaseClient? supabase})
      : _auth = auth ?? FirebaseAuth.instance,
        _supabase = supabase ?? Supabase.instance.client;

  final FirebaseAuth _auth;
  final SupabaseClient _supabase;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<EmployeeAccount> loadProfile(User user) async {
    final profile =
        _supabase.from('employee_profiles').select().eq('uid', user.uid);
    var data = await profile.maybeSingle();
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email ?? 'Employee';

    if (data == null) {
      await _supabase.from('employee_profiles').insert({
        'uid': user.uid,
        'email': user.email ?? '',
        'display_name': displayName,
        'role': 'employee',
      });
      data = await profile.single();
    }

    final roleName = data['role'] as String?;
    final role = switch (roleName) {
      'admin' => UserRole.admin,
      'employee' => UserRole.employee,
      _ => throw StateError(
          'Your account has an invalid role. Contact your administrator.',
        ),
    };
    final savedName = (data['display_name'] as String?)?.trim();

    return EmployeeAccount(
      uid: user.uid,
      email: user.email ?? '',
      displayName: savedName?.isNotEmpty == true ? savedName! : displayName,
      role: role,
    );
  }
}
