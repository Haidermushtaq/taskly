// widgets/overdue_banner.dart
// A red "N tasks are overdue" strip, shown at the top of the admin dashboard
// and the member task list. Individual TaskCards already turn their deadline
// line red, but that only helps once you scroll to the task — this puts the
// count where you land, so an overdue task can't be missed on either
// dashboard.
//
// It is presentational and self-hiding: give it the screen's task list and it
// counts the overdue ones itself (Task.isOverdue = has a deadline in the past
// and isn't done). When the count is zero it renders nothing, so screens can
// drop it in unconditionally.

import 'package:flutter/material.dart';
import '../models/task.dart';

class OverdueBanner extends StatelessWidget {
  final List<Task> tasks;
  // Spacing around the strip. The default lines it up with the task cards in
  // a full-width list; the admin dashboard passes a smaller one because its
  // column is already padded.
  final EdgeInsets margin;

  const OverdueBanner({
    super.key,
    required this.tasks,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final count = tasks.where((task) => task.isOverdue).length;

    // Nothing overdue: take up no space at all.
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // "1 task is" vs "3 tasks are".
              count == 1
                  ? '1 task is past its deadline'
                  : '$count tasks are past their deadline',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
