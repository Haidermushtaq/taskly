// screens/admin/create_task_screen.dart
// Admin form to create and assign a task inside one team. Loads the team's
// roster for the "assign to" dropdown, collects a title + description, a
// priority (low/medium/high, default medium) and an optional deadline, then
// calls TaskService.createTask. Uses setState only. On success it pops back
// to the task list, returning `true` so that screen knows to refresh.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../services/team_service.dart';
import '../../services/task_service.dart';

class CreateTaskScreen extends StatefulWidget {
  final Team team;

  const CreateTaskScreen({super.key, required this.team});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _teamService = TeamService();
  final _taskService = TaskService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Team roster available to assign to, loaded once.
  List<TeamMember> _members = [];
  // The id of the currently selected assignee (null until one is picked).
  String? _selectedUserId;
  // Optional deadline picked by the admin (null = no deadline).
  DateTime? _dueAt;
  // How urgent the task is. Starts at 'medium', the database default.
  String _priority = 'medium';

  bool _loadingMembers = true; // loading the dropdown data
  bool _saving = false; // running the insert
  String? _loadError; // error while loading the roster

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loadingMembers = true;
      _loadError = null;
    });
    try {
      final members = await _teamService.fetchTeamMembers(widget.team.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not load members: $e');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  // Pick a deadline: date first, then time of day. Cancel either dialog to
  // leave the deadline unset.
  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();

    // Basic validation: title and an assignee are required.
    if (title.isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and pick an assignee.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _taskService.createTask(
        teamId: widget.team.id,
        title: title,
        description: _descriptionController.text.trim(),
        assignedTo: _selectedUserId!,
        priority: _priority,
        dueAt: _dueAt,
      );
      if (mounted) Navigator.of(context).pop(true); // signal "created"
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create task: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Task')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadMembers, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Scrollable so the form still fits when the keyboard is up on a small
    // screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          // Dropdown of the team roster; the value is the member's user id.
          DropdownButtonFormField<String>(
            initialValue: _selectedUserId,
            decoration: const InputDecoration(labelText: 'Assign to'),
            items: _members
                .map((member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedUserId = value),
          ),
          const SizedBox(height: 16),
          // Priority picker: three segments, one per level, colored like the
          // priority chip that will appear on the task card.
          const Text(
            'Priority',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: priorityValues.map((value) {
              final selected = value == _priority;
              final color = priorityColor(value);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _priority = value),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor:
                          selected ? color.shade50 : Colors.transparent,
                      foregroundColor:
                          selected ? color.shade800 : Colors.grey.shade700,
                      side: BorderSide(
                        color: selected ? color.shade400 : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(priorityLabel(value)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // Deadline row: pick (or clear) an optional due date + time.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(
              _dueAt == null ? 'No deadline' : 'Due ${formatDue(_dueAt!)}',
            ),
            trailing: _dueAt == null
                ? TextButton(
                    onPressed: _pickDueDate,
                    child: const Text('Set deadline'),
                  )
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Remove deadline',
                    onPressed: () => setState(() => _dueAt = null),
                  ),
            onTap: _pickDueDate,
          ),
          const SizedBox(height: 12),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save task'),
                ),
        ],
      ),
    );
  }
}
