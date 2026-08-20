// screens/employee/my_tasks_screen.dart
// What a team member sees when they open a team: the tasks in that team
// assigned to them, as a list of TaskCards, each with a button to move the
// task to its next stage (pending -> in_progress -> done), under a red banner
// counting any of their tasks that are past their deadline and a search +
// filter bar (text, status, priority — no assignee filter, since every task
// here is already theirs). Uses setState only: a loading flag, an error
// message, the list of tasks, and the current filter.

import 'package:flutter/material.dart';
import '../../models/team.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/overdue_banner.dart';
import '../../widgets/task_filter_bar.dart';
import '../chat/chat_screen.dart';
import '../chat/members_screen.dart';

class MyTasksScreen extends StatefulWidget {
  final Team team;

  const MyTasksScreen({super.key, required this.team});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final _taskService = TaskService();

  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;

  // What the filter bar is set to; kept across reloads so advancing a task
  // doesn't reset your filters.
  final _filter = TaskFilter();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Fetch my tasks in this team and store them (or an error) in state.
  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _taskService.fetchMyTasks(widget.team.id);
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load tasks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Move one task to its next stage, then reload the list so the UI matches
  // the database.
  Future<void> _advance(Task task) async {
    final next = task.nextStatus;
    if (next == null) return; // already done, nothing to do.
    try {
      await _taskService.updateTaskStatus(taskId: task.id, newStatus: next);
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.team.name} - My Tasks'),
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

  // Picks what to show based on the current state.
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
              onPressed: _loadTasks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        message: 'No tasks assigned to you in this team yet.\n'
            'Check back later!',
      );
    }

    // Narrow the loaded list down to what matches the filter bar.
    final visible = _filter.apply(_tasks);

    // A pinned overdue banner and filter bar above a pull-to-refresh list of
    // task cards. Both sit outside the ListView so they stay visible while
    // scrolling; the banner renders nothing when no task is overdue.
    // The banner counts ALL my tasks, not just the visible ones, so hiding
    // something behind a filter can't hide the fact that it's overdue.
    return Column(
      children: [
        OverdueBanner(tasks: _tasks),
        // No assignee dropdown here: every task in this list is mine.
        TaskFilterBar(
          filter: _filter,
          onChanged: () => setState(() {}),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  message: 'No tasks match your search or filters.',
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final task = visible[index];
                      return TaskCard(
                        task: task,
                        // Only pass a callback when there's a next stage.
                        onAdvance: task.nextStatus == null
                            ? null
                            : () => _advance(task),
                        // These tasks are all assigned to me, so skip
                        // "Assigned to" and just show who created the task.
                        showCreator: true,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
