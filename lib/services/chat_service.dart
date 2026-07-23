// services/chat_service.dart
// All Supabase calls related to chat. Reading is done through Supabase
// Realtime streams so new messages appear live without refreshing:
// .stream() first loads existing rows, then pushes every insert. RLS decides
// which rows a user can see (team messages of their teams, plus their own
// DMs), so the client only adds display filtering.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  String get myUserId => _client.auth.currentUser!.id;

  // Live stream of one team's messages, oldest first. Realtime streams only
  // allow one server-side filter (team_id), so the split between the group
  // chat and a DM thread happens in the mappers below.
  Stream<List<Message>> _teamMessages(String teamId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('team_id', teamId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromMap).toList());
  }

  // Group chat: only messages addressed to the whole team.
  Stream<List<Message>> groupChat(String teamId) {
    return _teamMessages(teamId).map(
      (messages) => messages.where((m) => !m.isDirect).toList(),
    );
  }

  // Direct chat: only messages between me and one other member (either
  // direction). RLS already hides other people's DMs; this filter just
  // narrows to the one conversation being viewed.
  Stream<List<Message>> directChat(String teamId, String otherUserId) {
    return _teamMessages(teamId).map(
      (messages) => messages
          .where((m) =>
              m.isDirect &&
              ((m.senderId == myUserId && m.recipientId == otherUserId) ||
                  (m.senderId == otherUserId && m.recipientId == myUserId)))
          .toList(),
    );
  }

  // Send a message. recipientId null = to the whole team, set = DM.
  Future<void> sendMessage({
    required String teamId,
    required String content,
    String? recipientId,
  }) async {
    await _client.from('messages').insert({
      'team_id': teamId,
      'sender_id': myUserId,
      'recipient_id': recipientId,
      'content': content,
    });
  }
}
