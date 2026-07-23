// app_theme.dart
// The app's visual identity in one place: brand colors/gradient, status
// colors and labels, and avatar colors. Screens and widgets import this so
// every part of the app uses the same palette and looks consistent.

import 'package:flutter/material.dart';

// Brand colors: indigo -> violet. Used for headers and hero surfaces.
const Color brandStart = Color(0xFF6366F1);
const Color brandEnd = Color(0xFF8B5CF6);

const LinearGradient brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [brandStart, brandEnd],
);

// Soft near-white background used behind cards on every screen.
const Color appBackground = Color(0xFFF6F6FB);

// One color per task status, used on chips, rails, counts, and the profile
// overview: pending = orange, in progress = blue, done = green.
MaterialColor statusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'in_progress':
      return Colors.blue;
    case 'done':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

// Human-friendly label for a status value, e.g. in_progress -> In progress.
String statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'in_progress':
      return 'In progress';
    case 'done':
      return 'Done';
    default:
      return status;
  }
}

// Deterministic avatar color from a name, so the same team/person always
// gets the same color everywhere in the app.
const List<MaterialColor> _avatarPalette = [
  Colors.indigo,
  Colors.teal,
  Colors.deepOrange,
  Colors.pink,
  Colors.blue,
  Colors.green,
  Colors.purple,
  Colors.cyan,
];

MaterialColor avatarColor(String name) {
  return _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
}

// "12 Aug, 14:30" style label for deadlines, shared by every screen that
// shows a due date.
String formatDue(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]}, $hh:$mm';
}

// The app-wide ThemeData: Material 3 seeded from the brand color, soft
// background, white rounded cards, pill buttons, and filled text fields.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: brandStart);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: appBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: appBackground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Colors.grey.shade900,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Colors.grey.shade900),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F1F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandStart, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brandStart,
      foregroundColor: Colors.white,
    ),
  );
}
