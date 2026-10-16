enum UserRole { employee, admin }

class EmployeeAccount {
  const EmployeeAccount({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;
}
