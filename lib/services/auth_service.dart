import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/employee_account.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, SupabaseClient? supabase})
      : _auth = auth ?? FirebaseAuth.instance,
        _supabase = supabase ?? Supabase.instance.client;

  final FirebaseAuth _auth;
  final SupabaseClient _supabase;

  UserRole? requestedLoginRole;
  Completer<void>? _registrationProvisioning;
  Object? _registrationError;
  String? _pendingLoginError;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? takePendingLoginError() {
    final error = _pendingLoginError;
    _pendingLoginError = null;
    return error;
  }

  Future<void> signIn({
    required String email,
    required String password,
    required UserRole asRole,
    String? adminInviteId,
  }) async {
    requestedLoginRole = asRole;
    _registrationError = null;
    final inviteId = adminInviteId?.trim();
    final provisioning = Completer<void>();
    _registrationProvisioning = provisioning;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase sign-in did not return a user.');
      }
      await user.getIdToken(true);
      if (asRole == UserRole.admin && inviteId != null && inviteId.isNotEmpty) {
        final profile = await _supabase
            .from('employee_profiles')
            .select('role')
            .eq('uid', user.uid)
            .maybeSingle();
        if (profile?['role'] != 'admin') {
          await _redeemAdminInvite(
            inviteId: inviteId,
            displayName: user.displayName ?? user.email ?? 'Administrator',
          );
        }
      }
    } catch (error) {
      _registrationError = error;
      _pendingLoginError = _friendlyAuthError(error);
      if (_auth.currentUser != null) await _auth.signOut();
      rethrow;
    } finally {
      provisioning.complete();
      _registrationProvisioning = null;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole asRole,
    String? adminInviteId,
  }) async {
    requestedLoginRole = asRole;
    final provisioning = Completer<void>();
    _registrationProvisioning = provisioning;
    _registrationError = null;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase account creation did not return a user.');
      }
      await user.updateDisplayName(name.trim());
      await user.getIdToken(true);

      if (asRole == UserRole.admin) {
        final inviteId = adminInviteId?.trim();
        if (inviteId == null || inviteId.isEmpty) {
          throw const FormatException('An admin invite ID is required.');
        }
        await _redeemAdminInvite(
          inviteId: inviteId,
          displayName: name.trim(),
        );
      }
    } catch (error) {
      _registrationError = error;
      _pendingLoginError = _friendlyAuthError(error);
      if (asRole == UserRole.admin && _auth.currentUser != null) {
        await _auth.signOut();
      }
      rethrow;
    } finally {
      provisioning.complete();
      _registrationProvisioning = null;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> _redeemAdminInvite({
    required String inviteId,
    required String displayName,
  }) async {
    await _supabase.rpc(
      'redeem_admin_invite',
      params: {
        'p_invite_id': inviteId,
        'p_display_name': displayName,
      },
    );
  }

  String _friendlyAuthError(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is FormatException) return error.message;
    return error.toString();
  }

  Future<void> signOut() => _auth.signOut();

  Future<EmployeeAccount> loadProfile(User user) async {
    final provisioning = _registrationProvisioning;
    if (provisioning != null) {
      await provisioning.future;
      final registrationError = _registrationError;
      if (registrationError != null) {
        throw StateError('Account setup failed: $registrationError');
      }
    }

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
