// widgets/task_card.dart
// Reusable card that shows a single task: a status-colored rail down the left
// edge, title, description, deadline (red when overdue), a colored status
// chip, and optional actions. Kept presentational — it doesn't talk to
// Supabase itself. The parent screen passes the Task plus optional callbacks:
//   - onAdvance: members use it to move the task to its next stage. When
//     null (or the task is already done) no advance button is shown.
//   - onDelete: admins use it to delete the task. When null no delete button
//     is shown.
// This one widget serves both the member list and the admin list.
//   - showAssignee: admins turn this on to see who each task is assigned to
//     (shown prominently). Members leave it off — their tasks are all theirs.
//   - showCreator: shows "Created by" in a subtle line. Either list can use it.
// Both default off, and each line hides itself if the name wasn't joined.

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onAdvance;
  final VoidCallback? onDelete;
  final bool showAssignee;
  final bool showCreator;

  const TaskCard({
    super.key,
    required this.task,
    this.onAdvance,
    this.onDelete,
    this.showAssignee = false,
    this.showCreator = false,
  });

  @override
  Widget build(BuildContext context) {
    final next = task.nextStatus;
    final color = statusColor(task.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status rail: a thin colored strip that makes the task's state
            // visible at a glance even before reading the chip.
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Delete button only when the parent gave us onDelete.
                        if (onDelete != null)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                            ),
                            tooltip: 'Delete task',
                            onPressed: onDelete,
                          ),
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                    // Assignee: prominent, because on the admin list "who is
                    // this task for" is the key piece of info.
                    if (showAssignee && task.assignedToName != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: color.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Assigned to: ${task.assignedToName}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Creator: a quieter, secondary line.
                    if (showCreator && task.createdByName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Created by: ${task.createdByName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Deadline line: red + bold when overdue and not done.
                    if (task.dueAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: task.isOverdue
                                ? Colors.red.shade700
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            task.isOverdue
                                ? 'Overdue - was due ${formatDue(task.dueAt!)}'
                                : 'Due ${formatDue(task.dueAt!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: task.isOverdue
                                  ? Colors.red.shade700
                                  : Colors.grey.shade500,
                              fontWeight:
                                  task.isOverdue ? FontWeight.bold : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Colored status pill.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.shade200),
                          ),
                          child: Text(
                            statusLabel(task.status),
                            style: TextStyle(
                              color: color.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Advance button only when there's a next stage AND
                        // the parent gave us a callback to run.
                        if (next != null && onAdvance != null)
                          FilledButton.tonalIcon(
                            onPressed: onAdvance,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(statusLabel(next)),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
