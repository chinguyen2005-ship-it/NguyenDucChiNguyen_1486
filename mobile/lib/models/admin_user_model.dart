class AdminUserModel {
  final String id;
  final String username;
  final String? email;
  final bool emailConfirmed;
  final List<String> roles;
  final bool hasFace;
  final bool isLockedOut;

  AdminUserModel({
    required this.id,
    required this.username,
    this.email,
    required this.emailConfirmed,
    required this.roles,
    required this.hasFace,
    required this.isLockedOut,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'] ?? json['Roles'];
    final rolesList = <String>[];
    if (rolesRaw is List) {
      rolesList.addAll(rolesRaw.map((e) => e.toString()));
    }

    return AdminUserModel(
      id: (json['id'] ?? json['Id'] ?? '') as String,
      username:
          (json['username'] ??
                  json['userName'] ??
                  json['Username'] ??
                  json['UserName'] ??
                  '')
              as String,
      email: (json['email'] ?? json['Email']) as String?,
      emailConfirmed:
          (json['emailConfirmed'] ?? json['EmailConfirmed'] ?? false) as bool,
      roles: rolesList,
      hasFace: (json['hasFace'] ?? json['HasFace'] ?? false) as bool,
      isLockedOut:
          (json['isLockedOut'] ?? json['IsLockedOut'] ?? false) as bool,
    );
  }

  String get primaryRole {
    if (roles.contains('Admin')) return 'Admin';
    if (roles.contains('Parent')) return 'Parent';
    if (roles.contains('Child')) return 'Child';
    return roles.isNotEmpty ? roles.first : 'User';
  }

  bool get isChild => roles.contains('Child');
  bool get isParent => roles.contains('Parent');
  bool get isAdmin => roles.contains('Admin');
}
