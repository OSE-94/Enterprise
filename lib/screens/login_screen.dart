import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/employee_account.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.auth, super.key});

  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminInviteController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.employee;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.auth.takePendingLoginError();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _adminInviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        size: 42,
                        color: Color(0xFF315B50),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'PeoplePulse',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegistering
                            ? 'Create your ${_selectedRole == UserRole.admin ? 'admin' : 'employee'} account'
                            : 'Sign in to your team workspace',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64716B)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isRegistering ? 'Create account as' : 'Sign in as',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                            value: UserRole.employee,
                            label: Text('Employee'),
                            icon: Icon(Icons.person_outline_rounded),
                          ),
                          ButtonSegment(
                            value: UserRole.admin,
                            label: Text('Admin'),
                            icon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                        ],
                        selected: {_selectedRole},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedRole = selection.first;
                            _errorMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRole == UserRole.admin
                            ? 'Admin registration requires a one-time invite '
                                'ID issued by your organization.'
                            : 'Admin permissions are assigned by your '
                                'organization.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_isRegistering) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter your name'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        if (_selectedRole == UserRole.admin) ...[
                          TextFormField(
                            controller: _adminInviteController,
                            decoration: const InputDecoration(
                              labelText: 'One-time admin invite ID',
                              hintText: 'Paste the ID provided by your owner',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                            ),
                            validator: _validateAdminInvite,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                      if (!_isRegistering &&
                          _selectedRole == UserRole.admin) ...[
                        TextFormField(
                          controller: _adminInviteController,
                          decoration: const InputDecoration(
                            labelText: 'Admin invite ID (optional)',
                            hintText: 'Required only to redeem a new invite',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                          validator: _validateAdminInvite,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: _isRegistering
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isRegistering ? 'Create account' : 'Sign in'),
                      ),
                      if (!_isRegistering)
                        TextButton(
                          onPressed: _isSubmitting ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                  _isRegistering = !_isRegistering;
                                  _errorMessage = null;
                                }),
                        child: Text(
                          _isRegistering
                              ? 'Already registered? Sign in'
                              : 'New to PeoplePulse? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isRegistering) {
        await widget.auth.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          asRole: _selectedRole,
          adminInviteId: _selectedRole == UserRole.admin
              ? _adminInviteController.text
              : null,
        );
      } else {
        await widget.auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
          asRole: _selectedRole,
          adminInviteId: _selectedRole == UserRole.admin
              ? _adminInviteController.text
              : null,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _authError(error.code));
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Could not save your account: ${error.message}');
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address first.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.auth.sendPasswordReset(email);
      if (mounted) {
        setState(
          () => _errorMessage = 'Password reset instructions have been sent.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _authError(error.code));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _authError(String code) => switch (code) {
        'configuration-not-found' ||
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled for this Firebase project. '
              'In Firebase Console, open Authentication → Sign-in method and '
              'enable Email/Password.',
        'app-not-authorized' =>
          'This web app is not authorized for Firebase Authentication. '
              'Check the Firebase web app configuration and API key restrictions.',
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Choose a stronger password.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'Check your internet connection.',
        _ => 'Authentication failed ($code). Please try again.',
      };

  String? _validateAdminInvite(String? value) {
    if (_selectedRole != UserRole.admin) return null;
    final inviteId = value?.trim() ?? '';
    if (!_isRegistering && inviteId.isEmpty) return null;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(inviteId)) {
      return 'Enter the valid invite ID from your organization';
    }
    return null;
  }
}
