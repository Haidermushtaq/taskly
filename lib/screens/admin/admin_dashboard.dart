// screens/admin/admin_dashboard.dart
// What a team's admin sees when they open their team: the invite code to
// share (that's how members join), a red banner when any task in the team is
// past its deadline, simple task counts (total / pending /
// in progress / done), and buttons into the team's task list and its summary
// (per-employee breakdown). Uses setState only: it loads the team's tasks once
// and counts them in memory. Refreshes when returning from the task list,
// since tasks may have changed there.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../models/team.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/overdue_banner.dart';
import '../chat/chat_screen.dart';
import '../chat/members_screen.dart';
import 'all_tasks_screen.dart';
import 'team_summary_screen.dart';

class AdminDashboard extends StatefulWidget {
  final Team team;

  const AdminDashboard({super.key, required this.team});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _taskService = TaskService();

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _taskService.fetchAllTasks(widget.team.id);
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load counts: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Count how many tasks currently have the given status.
  int _countByStatus(String status) =>
      _tasks.where((task) => task.status == status).length;

  // Copy the invite code so the admin can share it with new members.
  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: widget.team.inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code copied.')),
      );
    }
  }

  // Open the team's task list; refresh counts when we come back.
  Future<void> _openAllTasks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AllTasksScreen(team: widget.team)),
    );
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Team chat',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(team: widget.team),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Members',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MembersScreen(team: widget.team),
              ),
            ),
          ),
        ],
      ),
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
            FilledButton(onPressed: _loadTasks, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Scrollable so the header, counts and both buttons still fit on a short
    // screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header: team identity + the invite code new members need.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'You are the admin of this team',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Invite code pill with a copy button.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.team.inviteCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.copy,
                            color: Colors.white, size: 18),
                        tooltip: 'Copy invite code',
                        onPressed: _copyInviteCode,
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Share this code so people can join',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Red strip when this team has tasks past their deadline. Hides
          // itself when there are none.
          OverdueBanner(
            tasks: _tasks,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          Text(
            'Overview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Count cards in a fixed 2-column grid; colors match the status
          // chip colors used on the task cards.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _CountCard(
                label: 'Total',
                count: _tasks.length,
                color: Colors.indigo,
              ),
              _CountCard(
                label: 'Pending',
                count: _countByStatus('pending'),
                color: Colors.orange,
              ),
              _CountCard(
                label: 'In progress',
                count: _countByStatus('in_progress'),
                color: Colors.blue,
              ),
              _CountCard(
                label: 'Done',
                count: _countByStatus('done'),
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openAllTasks,
            icon: const Icon(Icons.list_alt),
            label: const Text('Manage tasks'),
          ),
          const SizedBox(height: 12),
          // Deeper view: who has what, and how much is finished.
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamSummaryScreen(team: widget.team),
              ),
            ),
            icon: const Icon(Icons.insights),
            label: const Text('Team summary'),
          ),
        ],
      ),
    );
  }
}

// Small card showing a single count with its label, tinted with the status
// color. Purely presentational.
class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;

  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color.shade800)),
          ],
        ),
      ),
    );
  }
}
