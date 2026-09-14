class AppUser {
  final int id;
  final String login;
  final String fullName;
  final String role;
  final int? groupId;

  AppUser({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
    this.groupId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['user_id'] ?? json['id'],
        login: json['login'] ?? '',
        fullName: json['full_name'] ?? '',
        role: json['role'] ?? '',
        groupId: json['group_id'] as int?,
      );

  bool get isTeacher => role == 'teacher';
  bool get isMonitor => role == 'monitor';
  bool get isAdmin => role == 'admin';
}