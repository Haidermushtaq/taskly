// services/task_service.dart
// All Supabase calls related to tasks. Every query is scoped to one team,
// because tasks belong to teams now. RLS in the database is the real access
// control (members see their own tasks, team admins see all team tasks);
// the filters here just ask for what each screen needs.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TaskService {
  final SupabaseClient _client = Supabase.instance.client;

  // Columns to pull for every task, plus the names behind assigned_to and
  // created_by. Both are foreign keys into profiles, so we disambiguate with
  // the `profiles!<column>` hint and alias each embed (assignee / creator).
  // Task.fromMap reads assignee.name and creator.name from these.
  static const String _taskSelect =
      '*, assignee:profiles!assigned_to(name), creator:profiles!created_by(name)';

  // Fetch tasks in this team assigned to the current user, newest first.
  // Used by the member "my tasks" view.
  Future<List<Task>> fetchMyTasks(String teamId) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('tasks')
        .select(_taskSelect)
        .eq('team_id', teamId)
        .eq('assigned_to', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Task.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Fetch every task assigned to me across ALL my teams, newest first.
  // Used by the profile screen's task overview. RLS allows reading tasks
  // assigned to me, so no team filter is needed.
  Future<List<Task>> fetchAllMyTasks() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('tasks')
        .select(_taskSelect)
        .eq('assigned_to', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Task.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Fetch every task in this team, newest first. RLS only returns them all
  // for the team's admin; used by the admin "all tasks" view and the counts.
  Future<List<Task>> fetchAllTasks(String teamId) async {
    final data = await _client
        .from('tasks')
        .select(_taskSelect)
        .eq('team_id', teamId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Task.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Create and assign a task in this team, with a priority and an optional
  // deadline. Only the team admin can insert (enforced by RLS). Status
  // defaults to 'pending' in the database.
  Future<void> createTask({
    required String teamId,
    required String title,
    required String description,
    required String assignedTo,
    required String priority,
    DateTime? dueAt,
  }) async {
    final myId = _client.auth.currentUser!.id;
    await _client.from('tasks').insert({
      'team_id': teamId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': myId,
      'priority': priority,
      'due_at': dueAt?.toUtc().toIso8601String(),
    });
  }

  // Delete a task by id. Only the team admin can delete (enforced by RLS).
  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  // Move a task to a new status. The assignee (or the team admin) is allowed
  // to update by RLS. Used by the "move to next stage" button.
  Future<void> updateTaskStatus({
    required String taskId,
    required String newStatus,
  }) async {
    await _client
        .from('tasks')
        .update({'status': newStatus})
        .eq('id', taskId);
  }
}
