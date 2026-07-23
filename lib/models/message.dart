// models/message.dart
// Plain Dart class for one chat message. A message always belongs to a team;
// recipientId decides its kind:
//   - null  -> team message, visible to the whole team
//   - set   -> direct message, visible only to sender and recipient
// The chat screen maps senderId to a name using the team roster.

class Message {
  final String id;
  final String teamId;
  final String senderId;
  final String? recipientId;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      teamId: map['team_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String?,
      content: (map['content'] ?? '') as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  // True when this is a direct (person-to-person) message.
  bool get isDirect => recipientId != null;
}
