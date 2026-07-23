// screens/admin/all_tasks_screen.dart
// Admin view of every task in one team. Each task shows as a TaskCard with a
// delete button. A floating button opens the create-task screen; when that
// screen reports it created a task, we refresh the list. Uses setState only.

import 'package:flutter/material.dart';
import '../../models/team.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_card.dart';
import '../../widgets/empty_state.dart';
import 'create_task_screen.dart';

class AllTasksScreen extends StatefulWidget {
  final Team team;

  const AllTasksScreen({super.key, required this.team});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen> {
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
      if (mounted) setState(() => _error = 'Could not load tasks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Delete a task after a confirmation dialog, then refresh the list.
  Future<void> _delete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _taskService.deleteTask(task.id);
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete task: $e')),
        );
      }
    }
  }

  // Open the create-task screen; refresh if it created something.
  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(team: widget.team),
      ),
    );
    if (created == true) await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.team.name} - Tasks')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: 'Create task',
        child: const Icon(Icons.add),
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
            FilledButton(onPressed: _loadTasks, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_add,
        message: 'No tasks in this team yet.\nTap + to create and assign one.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          // Admin view: no advance button, but a delete button. Show who the
          // task is assigned to (prominent) and who created it.
          return TaskCard(
            task: task,
            onDelete: () => _delete(task),
            showAssignee: true,
            showCreator: true,
          );
        },
      ),
    );
  }
}
