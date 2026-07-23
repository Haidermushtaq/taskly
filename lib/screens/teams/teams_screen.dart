// screens/teams/teams_screen.dart
// Home screen after login. Lists every team the user belongs to (with their
// role in each), and offers the two entry points of the whole app:
//   - Create team: you become that team's admin
//   - Join team: enter an invite code, you become a member
// Tapping a team routes by your role in it: admin -> AdminDashboard,
// member -> MyTasksScreen. Uses setState only.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/empty_state.dart';
import '../admin/admin_dashboard.dart';
import '../employee/my_tasks_screen.dart';
import '../profile/profile_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final _teamService = TeamService();

  List<Team> _teams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teams = await _teamService.fetchMyTeams();
      if (mounted) setState(() => _teams = teams);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load teams: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Shared dialog with one text field. Used for both create (team name)
  // and join (invite code). Returns the entered text, or null on cancel.
  Future<String?> _promptText({
    required String title,
    required String label,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeam() async {
    final name = await _promptText(
      title: 'Create team',
      label: 'Team name',
      confirmLabel: 'Create',
    );
    if (name == null || name.isEmpty) return;

    try {
      await _teamService.createTeam(name);
      await _loadTeams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create team: $e')),
        );
      }
    }
  }

  Future<void> _joinTeam() async {
    final code = await _promptText(
      title: 'Join team',
      label: 'Invite code',
      confirmLabel: 'Join',
    );
    if (code == null || code.isEmpty) return;

    try {
      await _teamService.joinTeam(code);
      await _loadTeams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join team: $e')),
        );
      }
    }
  }

  // Route into a team based on my role in it.
  Future<void> _openTeam(Team team) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => team.isAdmin
            ? AdminDashboard(team: team)
            : MyTasksScreen(team: team),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const LogoutButton(),
        ],
      ),
      body: _buildBody(),
      // Two actions side by side: create a team or join one with a code.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createTeam,
                  icon: const Icon(Icons.add),
                  label: const Text('Create team'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _joinTeam,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join team'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadTeams, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_teams.isEmpty) {
      return const EmptyState(
        icon: Icons.groups,
        message: 'You are not in any team yet.\n'
            'Create one to lead it, or join with an invite code.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        itemCount: _teams.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final team = _teams[index];
          final color = avatarColor(team.name);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: color.shade100,
                child: Text(
                  team.name.isEmpty ? '?' : team.name[0].toUpperCase(),
                  style: TextStyle(
                    color: color.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                team.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: team.isAdmin
                            ? Colors.amber.shade100
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        team.isAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: team.isAdmin
                              ? Colors.amber.shade900
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTeam(team),
            ),
          );
        },
      ),
    );
  }
}
