// screens/admin/team_summary_screen.dart
// The admin's overview of how a team is doing, opened with the "Team summary"
// button on the admin dashboard. Two parts:
//   1. Whole team — how many tasks are completed vs still open, as a
//      percentage with a progress bar, plus counts per status and overdue.
//   2. Per employee — one card for every member of the team (including people
//      with no tasks yet) showing their totals: pending, in progress, done,
//      overdue, and their own completion bar.
// It loads the team's tasks and its roster once, then does all the counting in
// memory — there is no aggregate query, just a loop over the task list, which
// keeps the whole thing easy to read. Uses setState only.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/task.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../services/task_service.dart';
import '../../services/team_service.dart';

class TeamSummaryScreen extends StatefulWidget {
  final Team team;

  const TeamSummaryScreen({super.key, required this.team});

  @override
  State<TeamSummaryScreen> createState() => _TeamSummaryScreenState();
}

class _TeamSummaryScreenState extends State<TeamSummaryScreen> {
  final _taskService = TaskService();
  final _teamService = TeamService();

  List<Task> _tasks = [];
  List<TeamMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Tasks give us the numbers; the roster gives us the people, so members
  // with nothing assigned still show up (that's useful information too).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _taskService.fetchAllTasks(widget.team.id);
      final members = await _teamService.fetchTeamMembers(widget.team.id);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _members = members;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load summary: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _countByStatus(String status) =>
      _tasks.where((task) => task.status == status).length;

  int get _overdueCount => _tasks.where((task) => task.isOverdue).length;

  // Build one stats row per team member, then append an "Unassigned" row if
  // any task points at somebody who is no longer on the roster.
  List<_MemberStats> _buildMemberStats() {
    final stats = <String, _MemberStats>{};
    for (final member in _members) {
      stats[member.userId] = _MemberStats(member.name);
    }

    for (final task in _tasks) {
      final id = task.assignedTo;
      // A task whose assignee left the team still counts somewhere.
      final entry = (id != null && stats.containsKey(id))
          ? stats[id]!
          : stats.putIfAbsent(
              'unassigned',
              () => _MemberStats(task.assignedToName ?? 'Former member'),
            );
      entry.add(task);
    }

    final list = stats.values.toList();
    // Busiest people first, so the admin sees where the load is.
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.team.name} - Summary')),
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
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final total = _tasks.length;
    final done = _countByStatus('done');
    // "Open" is everything not finished: pending + in progress.
    final open = total - done;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- 1. Whole-team completion ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completed vs open',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0 ? 'No tasks yet' : '$done of $total done',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressBar(
                  done: done,
                  total: total,
                  background: Colors.white24,
                  fill: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  total == 0
                      ? 'Create a task to start tracking progress'
                      : '$open still open - ${_percent(done, total)}% complete',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status counts for the whole team, same colors as everywhere else.
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Pending',
                  count: _countByStatus('pending'),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'In progress',
                  count: _countByStatus('in_progress'),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Done',
                  count: done,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          // Overdue gets its own full-width red line when there is any.
          if (_overdueCount > 0) ...[
            const SizedBox(height: 10),
            _StatTile(
              label: 'Overdue',
              count: _overdueCount,
              color: Colors.red,
              wide: true,
            ),
          ],
          const SizedBox(height: 24),

          // --- 2. Per-employee breakdown ---
          Text(
            'Per employee',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            const Text('Nobody has joined this team yet.')
          else
            ..._buildMemberStats().map((stats) => _MemberCard(stats: stats)),
        ],
      ),
    );
  }
}

// Whole-number percentage, guarding against a divide by zero on an empty team.
int _percent(int part, int whole) =>
    whole == 0 ? 0 : ((part / whole) * 100).round();

// The counts for one person. Filled in by add() as we walk the task list.
class _MemberStats {
  final String name;
  int total = 0;
  int pending = 0;
  int inProgress = 0;
  int done = 0;
  int overdue = 0;

  _MemberStats(this.name);

  void add(Task task) {
    total++;
    if (task.isOverdue) overdue++;
    switch (task.status) {
      case 'pending':
        pending++;
      case 'in_progress':
        inProgress++;
      case 'done':
        done++;
    }
  }
}

// One card per person: avatar, name, "x of y done" with a progress bar, and a
// row of small colored counts.
class _MemberCard extends StatelessWidget {
  final _MemberStats stats;

  const _MemberCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(stats.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.shade100,
                  child: Text(
                    stats.name.isEmpty ? '?' : stats.name[0].toUpperCase(),
                    style: TextStyle(
                      color: color.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stats.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  stats.total == 0
                      ? 'No tasks'
                      : '${stats.done}/${stats.total} done',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            if (stats.total > 0) ...[
              const SizedBox(height: 10),
              _ProgressBar(
                done: stats.done,
                total: stats.total,
                background: Colors.grey.shade200,
                fill: Colors.green,
              ),
              const SizedBox(height: 10),
              // Only the non-zero counts, so a card stays uncluttered.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (stats.pending > 0)
                    _MiniCount(
                      label: 'Pending',
                      count: stats.pending,
                      color: Colors.orange,
                    ),
                  if (stats.inProgress > 0)
                    _MiniCount(
                      label: 'In progress',
                      count: stats.inProgress,
                      color: Colors.blue,
                    ),
                  if (stats.done > 0)
                    _MiniCount(
                      label: 'Done',
                      count: stats.done,
                      color: Colors.green,
                    ),
                  if (stats.overdue > 0)
                    _MiniCount(
                      label: 'Overdue',
                      count: stats.overdue,
                      color: Colors.red,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// A flat completion bar: filled portion = done / total.
class _ProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final Color background;
  final Color fill;

  const _ProgressBar({
    required this.done,
    required this.total,
    required this.background,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : done / total,
        minHeight: 8,
        backgroundColor: background,
        valueColor: AlwaysStoppedAnimation<Color>(fill),
      ),
    );
  }
}

// Big number over a label, tinted with a status color. Used for the team-wide
// counts under the header.
class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;
  final bool wide; // lay out horizontally instead of stacked

  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final number = Text(
      '$count',
      style: TextStyle(
        color: color.shade800,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
    final text = Text(
      label,
      style: TextStyle(color: color.shade800, fontSize: 13),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: wide
          ? Row(children: [number, const SizedBox(width: 8), text])
          : Column(children: [number, const SizedBox(height: 2), text]),
    );
  }
}

// Small "Pending 3" style chip inside a member card.
class _MiniCount extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;

  const _MiniCount({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
