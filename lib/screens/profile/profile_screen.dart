// screens/profile/profile_screen.dart
// The logged-in user's overview page, reached from the teams screen app bar.
// Shows three things:
//   1. Who I am (name from profiles, email from the auth session)
//   2. Every team I'm in, with my role in each
//   3. Every task assigned to me across all teams, grouped by status
//      (pending / in progress / done), each with its deadline if set and a
//      red "overdue" marker when the deadline has passed.
// Read-only screen: all data loads once in initState. Uses setState only.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/profile.dart';
import '../../models/team.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/team_service.dart';
import '../../services/task_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _teamService = TeamService();
  final _taskService = TaskService();

  Profile? _profile;
  List<Team> _teams = [];
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  // Load profile, teams and tasks together; show whatever fails as one error.
  Future<void> _loadEverything() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _authService.fetchMyProfile();
      final teams = await _teamService.fetchMyTeams();
      final tasks = await _taskService.fetchAllMyTasks();
      if (mounted) {
        setState(() {
          _profile = profile;
          _teams = teams;
          _tasks = tasks;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Task> _byStatus(String status) =>
      _tasks.where((t) => t.status == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _buildBody(),
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
            FilledButton(
              onPressed: _loadEverything,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEverything,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- 1. Identity header on the brand gradient ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    (_profile?.name.isEmpty ?? true)
                        ? '?'
                        : _profile!.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: brandStart,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _authService.myEmail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- 2. My teams ---
          Text('My teams (${_teams.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_teams.isEmpty)
            const Text('Not in any team yet.')
          else
            ..._teams.map(
              (team) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: avatarColor(team.name).shade100,
                    child: Text(
                      team.name.isEmpty ? '?' : team.name[0].toUpperCase(),
                      style: TextStyle(
                        color: avatarColor(team.name).shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    team.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Chip(
                    label: Text(team.isAdmin ? 'Admin' : 'Member'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // --- 3. My tasks grouped by status ---
          Text('My tasks (${_tasks.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_tasks.isEmpty)
            const Text('No tasks assigned to you.')
          else ...[
            _TaskGroup(
              title: 'Pending',
              color: Colors.orange,
              tasks: _byStatus('pending'),
            ),
            _TaskGroup(
              title: 'In progress',
              color: Colors.blue,
              tasks: _byStatus('in_progress'),
            ),
            _TaskGroup(
              title: 'Done',
              color: Colors.green,
              tasks: _byStatus('done'),
            ),
          ],
        ],
      ),
    );
  }
}

// One collapsible-looking section per status: colored header with a count,
// then a compact row per task showing its deadline (red when overdue).
class _TaskGroup extends StatelessWidget {
  final String title;
  final MaterialColor color;
  final List<Task> tasks;

  // Deadline text comes from the shared formatDue() in app_theme.dart.
  const _TaskGroup({
    required this.title,
    required this.color,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${tasks.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
          const SizedBox(height: 4),
          ...tasks.map(
            (task) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.circle, size: 10, color: color),
              title: Text(task.title),
              subtitle: task.dueAt == null
                  ? null
                  : Text(
                      task.isOverdue
                          ? 'Overdue - was due ${formatDue(task.dueAt!)}'
                          : 'Due ${formatDue(task.dueAt!)}',
                      style: TextStyle(
                        color: task.isOverdue
                            ? Colors.red.shade700
                            : Colors.grey.shade600,
                        fontWeight:
                            task.isOverdue ? FontWeight.bold : null,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
