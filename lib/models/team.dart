// models/team.dart
// Plain Dart class for a team the logged-in user belongs to. Built from a
// team_members row joined with its teams row, so it carries BOTH the team
// info and *my* role in that team ('admin' if I created it, 'member' if I
// joined with an invite code). The teams screen uses this to route: tapping
// a team opens the admin dashboard or the member task list based on myRole.

class Team {
  final String id;
  final String name;
  final String inviteCode;
  final String myRole; // 'admin' | 'member'

  Team({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.myRole,
  });

  // Build from a team_members row with the embedded teams row, e.g.:
  // { "role": "admin", "teams": { "id": ..., "name": ..., "invite_code": ... } }
  factory Team.fromMemberRow(Map<String, dynamic> row) {
    final team = row['teams'] as Map<String, dynamic>;
    return Team(
      id: team['id'] as String,
      name: team['name'] as String,
      inviteCode: team['invite_code'] as String,
      myRole: row['role'] as String,
    );
  }

  // Convenience flag so routing code reads clearly.
  bool get isAdmin => myRole == 'admin';
}
