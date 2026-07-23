// screens/chat/chat_screen.dart
// Chat inside a team. One screen serves both modes:
//   - group chat: `other` is null -> messages go to the whole team
//   - direct chat: `other` is a member -> private messages with that person
// Messages arrive live through a Supabase Realtime stream (StreamBuilder),
// so no manual refresh is needed. Sender names come from the team roster,
// loaded once. Uses setState only for the roster/sending state.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../models/message.dart';
import '../../services/chat_service.dart';
import '../../services/team_service.dart';

class ChatScreen extends StatefulWidget {
  final Team team;
  final TeamMember? other; // null = team group chat

  const ChatScreen({super.key, required this.team, this.other});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _teamService = TeamService();
  final _textController = TextEditingController();

  // user id -> display name, for labeling group chat messages.
  Map<String, String> _names = {};
  bool _sending = false;

  bool get _isGroup => widget.other == null;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Load the roster once so we can show a name next to each message.
  Future<void> _loadNames() async {
    try {
      final members = await _teamService.fetchTeamMembers(widget.team.id);
      if (mounted) {
        setState(() {
          _names = {for (final m in members) m.userId: m.name};
        });
      }
    } catch (_) {
      // Names are cosmetic; the chat still works without them.
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        teamId: widget.team.id,
        content: text,
        recipientId: widget.other?.userId,
      );
      _textController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isGroup
        ? '${widget.team.name} - Team chat'
        : widget.other!.name;

    // Pick the right live stream for this mode.
    final stream = _isGroup
        ? _chatService.groupChat(widget.team.id)
        : _chatService.directChat(widget.team.id, widget.other!.userId);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          // Message list fills the screen above the input bar.
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load chat: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hi!'));
                }

                // reverse:true keeps the view pinned to the newest message,
                // so we render the list newest-first.
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == _chatService.myUserId,
                      // Show sender names only in group chat.
                      senderName: _isGroup
                          ? (_names[message.senderId] ?? 'Unknown')
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          // Input bar: text field + send button.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// One chat bubble. Mine align right, filled with the brand color and white
// text; others align left on white, with the sender's name above (group chat
// only). The corner nearest the sender is squared, like other messengers.
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final String? senderName;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
  });

  // "14:05" style timestamp.
  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? brandStart : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: avatarColor(senderName!).shade700,
                  ),
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.grey.shade900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _time(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
