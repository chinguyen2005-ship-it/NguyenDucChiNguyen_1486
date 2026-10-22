class UserProfile {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final List<String> roles;
  final String primaryRole;
  final bool emailConfirmed;
  final bool hasFace;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.roles,
    String? primaryRole,
    required this.emailConfirmed,
    this.hasFace = false,
    this.createdAt,
  }) : primaryRole = primaryRole ?? (roles.isNotEmpty ? roles.first : 'Parent');

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Handle both group backend (PascalCase) and standard (camelCase)
    final usernameVal = (json['Username'] ?? json['username'] ?? '') as String;
    final emailVal = (json['Email'] ?? json['email'] ?? '') as String;
    final initialsVal =
        (json['Initials'] ??
                json['initials'] ??
                json['FullName'] ??
                json['fullName'] ??
                usernameVal)
            as String;
    final roleVal = (json['Role'] ?? json['role'] ?? '') as String;

    List<String> rolesList = [];
    final rawRoles = json['Roles'] ?? json['roles'];
    if (rawRoles is List) {
      rolesList = rawRoles.map((e) => e.toString()).toList();
    }
    if (rolesList.isEmpty && roleVal.isNotEmpty) {
      rolesList.add(roleVal);
    }

    final emailConfirmedVal =
        (json['EmailConfirmed'] ?? json['emailConfirmed'] ?? false) as bool;
    final hasFaceVal = (json['HasFace'] ?? json['hasFace'] ?? false) as bool;

    return UserProfile(
      id: (json['Id'] ?? json['id'] ?? usernameVal) as String,
      username: usernameVal,
      email: emailVal,
      fullName: initialsVal,
      roles: rolesList,
      primaryRole: roleVal.isNotEmpty
          ? roleVal
          : (rolesList.isNotEmpty ? rolesList.first : 'Parent'),
      emailConfirmed: emailConfirmedVal,
      hasFace: hasFaceVal,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'roles': roles,
      'primaryRole': primaryRole,
      'emailConfirmed': emailConfirmed,
      'hasFace': hasFace,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get isAdmin => primaryRole == 'Admin' || roles.contains('Admin');
  bool get isParent => primaryRole == 'Parent' || roles.contains('Parent');
  bool get isChild => primaryRole == 'Child' || roles.contains('Child');
}

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final String? tokenType;
  final int? expiresIn;
  final UserProfile? user;
  final bool requiresOtp;
  final bool requiresEmailConfirmation;
  final String? email;
  final String? role;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.tokenType,
    this.expiresIn,
    this.user,
    this.requiresOtp = false,
    this.requiresEmailConfirmation = false,
    this.email,
    this.role,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Group backend uses "Status", "Message", "Token", "Role", "RequiresOtp", "RequiresEmailConfirmation"
    final status =
        (json['Status'] ?? json['status'] ?? json['success'] ?? false) as bool;
    final message = (json['Message'] ?? json['message'] ?? '') as String;
    final token = (json['Token'] ?? json['token']) as String?;
    final role = (json['Role'] ?? json['role']) as String?;
    final requiresOtp =
        (json['RequiresOtp'] ?? json['requiresOtp'] ?? false) as bool;
    final requiresEmailConf =
        (json['RequiresEmailConfirmation'] ??
                json['requiresEmailConfirmation'] ??
                false)
            as bool;
    final email = (json['Email'] ?? json['email']) as String?;
    final username = (json['Username'] ?? json['username']) as String?;

    UserProfile? userProfile;
    if (json['user'] != null) {
      userProfile = UserProfile.fromJson(json['user'] as Map<String, dynamic>);
    } else if (username != null && username.isNotEmpty) {
      userProfile = UserProfile(
        id: username,
        username: username,
        email: email ?? '',
        fullName: username,
        roles: role != null ? [role] : [],
        primaryRole: role ?? 'Parent',
        emailConfirmed: true,
      );
    }

    return AuthResponse(
      success: status,
      message: message,
      token: token,
      tokenType: 'Bearer',
      expiresIn: (json['ExpiresInSeconds'] ?? json['expiresIn']) as int?,
      user: userProfile,
      requiresOtp: requiresOtp,
      requiresEmailConfirmation: requiresEmailConf,
      email: email,
      role: role,
    );
  }
}
