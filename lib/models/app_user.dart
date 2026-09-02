import 'role.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final int? roleId;
  final int? ownerId;
  final Role? role;
  final List<String> permissions;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.roleId,
    this.ownerId,
    this.role,
    required this.permissions,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      roleId: json['role_id'],
      ownerId: json['owner_id'],
      role: json['role'] != null ? Role.fromJson(json['role']) : null,
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
    );
  }

  /// Owners have full access regardless of the permissions list.
  bool get isOwner => role?.name == 'owner';

  bool hasPermission(String permission) {
    if (isOwner) return true;
    return permissions.contains(permission);
  }
}