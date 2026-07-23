// models/task.dart
// Plain Dart class representing a row from the `tasks` table. Used by both the
// employee "my tasks" list and (later) the admin screens. `fromMap` converts
// Supabase JSON into a typed Task. `nextStatus` encodes the allowed status
// progression pending -> in_progress -> done so the UI knows what button to
// show.

class Task {
  final String id;
  final String title;
  final String description;
  final String? assignedTo;
  final String? createdBy;
  final String? teamId; // which team this task belongs to
  final String status; // 'pending' | 'in_progress' | 'done'
  final DateTime? dueAt; // optional deadline set by the admin
  // Display names behind assigned_to / created_by, filled in only when the
  // query joins profiles (see TaskService). Null when not fetched or unknown.
  final String? assignedToName;
  final String? createdByName;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.createdBy,
    required this.teamId,
    required this.status,
    required this.dueAt,
    this.assignedToName,
    this.createdByName,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: (map['title'] ?? '') as String,
      // description can be null in the DB; fall back to empty string.
      description: (map['description'] ?? '') as String,
      assignedTo: map['assigned_to'] as String?,
      createdBy: map['created_by'] as String?,
      teamId: map['team_id'] as String?,
      status: map['status'] as String,
      dueAt: map['due_at'] == null
          ? null
          : DateTime.parse(map['due_at'] as String).toLocal(),
      // Joined profile rows arrive as nested objects: {'name': ...} or null.
      assignedToName: _nameOf(map['assignee']),
      createdByName: _nameOf(map['creator']),
    );
  }

  // Pulls `name` out of an embedded profiles object, tolerating a missing or
  // null join (returns null so the UI can just hide the line).
  static String? _nameOf(dynamic embed) {
    if (embed is Map<String, dynamic>) return embed['name'] as String?;
    return null;
  }

  // Overdue = has a deadline in the past and still isn't done.
  bool get isOverdue =>
      dueAt != null && status != 'done' && dueAt!.isBefore(DateTime.now());

  // The next status in the workflow, or null if the task is already done.
  // Employees use this to move a task forward one stage at a time.
  String? get nextStatus {
    switch (status) {
      case 'pending':
        return 'in_progress';
      case 'in_progress':
        return 'done';
      default:
        return null; // 'done' has no next stage.
    }
  }
}
