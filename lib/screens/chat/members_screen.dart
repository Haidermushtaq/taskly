// screens/chat/members_screen.dart
// The team roster. Shows every member with their per-team role; tapping a
// member (other than yourself) opens a private chat with them. Reached from
// both the admin dashboard and the member task view. Uses setState only.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../services/team_service.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class MembersScreen extends StatefulWidget {
  final Team team;

  const MembersScreen({super.key, required this.team});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _teamService = TeamService();
  final _chatService = ChatService();

  List<TeamMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await _teamService.fetchTeamMembers(widget.team.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load members: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDirectChat(TeamMember member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(team: widget.team, other: member),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.team.name} - Members')),
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
            FilledButton(onPressed: _loadMembers, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMe = member.userId == _chatService.myUserId;
        final color = avatarColor(member.name);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: color.shade100,
              child: Text(
                member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                style: TextStyle(
                  color: color.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              isMe ? '${member.name} (you)' : member.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(member.role == 'admin' ? 'Admin' : 'Member'),
            // Tap anyone except yourself to start a private chat.
            trailing: isMe
                ? null
                : Icon(Icons.chat_bubble_outline, color: brandStart),
            onTap: isMe ? null : () => _openDirectChat(member),
          ),
        );
      },
    );
  }
}
