// widgets/task_filter_bar.dart
// The search + filter strip that sits above a task list, plus the small
// TaskFilter object that holds what the user picked.
//
// Both task lists use it: the admin "all tasks" screen (search, status,
// priority and assignee) and the member "my tasks" screen (search, status and
// priority — every task there is already theirs, so no assignee filter).
//
// Filtering happens in memory. The screen has already fetched its list of
// tasks from Supabase, so narrowing it down is just a `where` over that
// list — no extra queries, and the filter reacts instantly as you type. The
// screen keeps one TaskFilter in its state, hands it to this bar, and calls
// filter.apply(tasks) when building the list.

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/task.dart';

// What the user is currently filtering by. Fields are mutable and the screens
// change them inside setState, which is the pattern used everywhere in this
// app. A null status/priority/assignee means "any".
class TaskFilter {
  String query = ''; // free text typed in the search box
  String? status; // 'pending' | 'in_progress' | 'done'
  String? priority; // 'low' | 'medium' | 'high'
  String? assigneeId; // profiles.id of the person to show tasks for

  // True when at least one filter is set, used to show the "Clear" button and
  // a "no matches" message instead of the normal empty state.
  bool get isActive =>
      query.trim().isNotEmpty ||
      status != null ||
      priority != null ||
      assigneeId != null;

  // Reset everything back to "show all".
  void clear() {
    query = '';
    status = null;
    priority = null;
    assigneeId = null;
  }

  // Keep only the tasks matching every active filter. A task matches the text
  // search if the words appear in its title or its description.
  List<Task> apply(List<Task> tasks) {
    final text = query.trim().toLowerCase();

    return tasks.where((task) {
      if (status != null && task.status != status) return false;
      if (priority != null && task.priority != priority) return false;
      if (assigneeId != null && task.assignedTo != assigneeId) return false;
      if (text.isNotEmpty) {
        final haystack =
            '${task.title} ${task.description}'.toLowerCase();
        if (!haystack.contains(text)) return false;
      }
      return true;
    }).toList();
  }
}

class TaskFilterBar extends StatefulWidget {
  // The filter this bar edits. The bar mutates it and then calls onChanged so
  // the parent screen can setState and rebuild its list.
  final TaskFilter filter;
  final VoidCallback onChanged;

  // People who can be filtered on, as user id -> display name. Pass null (the
  // default) to hide the assignee dropdown entirely — that's the member view.
  final Map<String, String>? assignees;

  const TaskFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.assignees,
  });

  @override
  State<TaskFilterBar> createState() => _TaskFilterBarState();
}

class _TaskFilterBarState extends State<TaskFilterBar> {
  // Owned here (not by the screen) so the text box keeps its cursor position
  // while the list rebuilds on every keystroke.
  late final TextEditingController _searchController =
      TextEditingController(text: widget.filter.query);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Every control funnels through here: change the filter, tell the parent.
  void _update(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final assignees = widget.assignees;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          // Free-text search over title and description.
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              // An X to empty the box, only while there's something in it.
              suffixIcon: widget.filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _update(() => widget.filter.query = '');
                      },
                    ),
            ),
            onChanged: (value) => _update(() => widget.filter.query = value),
          ),
          const SizedBox(height: 8),
          // Status and priority side by side; both fit on one row on a phone.
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  hint: 'Any status',
                  value: widget.filter.status,
                  values: statusValues,
                  labelOf: statusLabel,
                  colorOf: statusColor,
                  onChanged: (value) =>
                      _update(() => widget.filter.status = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  hint: 'Any priority',
                  value: widget.filter.priority,
                  values: priorityValues,
                  labelOf: priorityLabel,
                  colorOf: priorityColor,
                  onChanged: (value) =>
                      _update(() => widget.filter.priority = value),
                ),
              ),
            ],
          ),
          // Assignee filter: admin view only.
          if (assignees != null) ...[
            const SizedBox(height: 8),
            _FilterDropdown(
              hint: 'Anyone',
              value: widget.filter.assigneeId,
              values: assignees.keys.toList(),
              labelOf: (id) => assignees[id] ?? 'Unknown',
              onChanged: (value) =>
                  _update(() => widget.filter.assigneeId = value),
              icon: Icons.person_outline,
            ),
          ],
          // One tap to get back to the full list.
          if (widget.filter.isActive)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _update(widget.filter.clear);
                },
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }
}

// One dropdown with an "any" option on top. Plain DropdownButton (not the
// form-field version) so its selection always mirrors the TaskFilter, even
// when "Clear filters" resets it from outside.
class _FilterDropdown extends StatelessWidget {
  final String hint; // label for the "no filter" option
  final String? value; // currently selected value, null = no filter
  final List<String> values; // the selectable raw values
  final String Function(String value) labelOf; // value -> display text
  final MaterialColor Function(String value)? colorOf; // optional color dot
  final ValueChanged<String?> onChanged;
  final IconData? icon;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.arrow_drop_down),
        style: TextStyle(fontSize: 14, color: Colors.grey.shade900),
        items: [
          // The "off" option, shown greyed out like a hint.
          DropdownMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                ],
                Text(hint, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          ...values.map(
            (item) => DropdownMenuItem<String?>(
              value: item,
              child: Row(
                children: [
                  // Colored dot so the dropdown reads like the chips on the
                  // cards. Skipped for people (no color of their own).
                  if (colorOf != null) ...[
                    Icon(Icons.circle, size: 10, color: colorOf!(item)),
                    const SizedBox(width: 6),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                  ],
                  // Long names shouldn't blow up the row.
                  Expanded(
                    child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
