// services/team_service.dart
// All Supabase calls related to teams. Creating and joining teams go through
// database RPC functions (create_team / join_team) because those need to
// write to tables that clients can't insert into directly — the function
// runs with elevated rights, validates, and keeps the logic in one place.
// Reads (my teams, a team's roster) are plain selects guarded by RLS.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';
import '../models/team_member.dart';

class TeamService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fetch every team the current user belongs to, along with their role in
  // each. Reads team_members (RLS: only own rows' teams) with the team row
  // embedded, ordered by when they joined.
  Future<List<Team>> fetchMyTeams() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('team_members')
        .select('role, teams(id, name, invite_code)')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => Team.fromMemberRow(row as Map<String, dynamic>))
        .toList();
  }

  // Create a new team. The DB function inserts the team, generates its
  // invite code, and adds the current user as its admin. Returns nothing;
  // callers refresh the team list afterwards.
  Future<void> createTeam(String name) async {
    await _client.rpc('create_team', params: {'team_name': name});
  }

  // Join an existing team using its invite code. The DB function looks up
  // the code and adds the current user as a member (rejects bad codes).
  Future<void> joinTeam(String code) async {
    await _client.rpc('join_team', params: {'code': code});
  }

  // Fetch everyone in a team (with names from profiles). Used by the admin
  // create-task screen for the "assign to" dropdown.
  Future<List<TeamMember>> fetchTeamMembers(String teamId) async {
    final data = await _client
        .from('team_members')
        .select('user_id, role, profiles(name)')
        .eq('team_id', teamId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => TeamMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
