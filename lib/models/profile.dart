// models/profile.dart
// Plain Dart class representing a row from the `profiles` table: the user's
// identity (name). Roles are NOT here — they are per-team in team_members.
// Used by the profile screen to show the logged-in user's info.

class Profile {
  final String id;
  final String name;

  Profile({required this.id, required this.name});

  // Build a Profile from the map Supabase gives us for a profiles row.
  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      // name can be null in the DB; fall back to an empty string.
      name: (map['name'] ?? '') as String,
    );
  }
}
