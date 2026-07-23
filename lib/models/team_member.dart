// models/team_member.dart
// Plain Dart class for one person in a team: their user id, display name
// (joined from profiles) and per-team role. Used by the admin create-task
// screen to build the "assign to" dropdown from the team roster.

class TeamMember {
  final String userId;
  final String name;
  final String role; // 'admin' | 'member'

  TeamMember({
    required this.userId,
    required this.name,
    required this.role,
  });

  // Build from a team_members row with the embedded profiles row, e.g.:
  // { "user_id": ..., "role": "member", "profiles": { "name": ... } }
  factory TeamMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return TeamMember(
      userId: map['user_id'] as String,
      name: (profile?['name'] ?? 'Unknown') as String,
      role: map['role'] as String,
    );
  }
}
