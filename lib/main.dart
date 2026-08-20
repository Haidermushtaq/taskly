// main.dart
// App entry point. Does three jobs:
//   1. Initializes Supabase before the app runs (so auth/session is ready).
//   2. Starts the notification service, which watches the tasks table over
//      Supabase Realtime and raises a phone notification when a task is
//      assigned to you or when a task you created changes status. It hooks
//      itself onto the auth state, so it only runs while someone is logged in.
//   3. Hosts the "auth gate": a widget that listens to auth state changes and
//      shows LoginScreen when logged out, or TeamsScreen when logged in.
// Roles are per-team now, so there is no global role routing here — the
// teams screen routes into each team as admin or member.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/teams/teams_screen.dart';

// Supabase project credentials, read at compile time from a .env file passed
// via `--dart-define-from-file=.env` (see .env.example). They are kept out of
// source control. The anon key is public by design; the real security is
// enforced by Row Level Security (RLS) in the database.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  // Ensure Flutter's binding is ready before we do async setup.
  WidgetsFlutterBinding.ensureInitialized();

  // Fail loudly if the .env values were not supplied, instead of hitting a
  // confusing Supabase error later. Run with:
  //   flutter run --dart-define-from-file=.env
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
      'Run with: flutter run --dart-define-from-file=.env',
    );
  }

  // Connect to Supabase. This restores any persisted session automatically.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Prepare notifications (permission prompt + realtime listeners). Must come
  // after Supabase.initialize, because it uses the auth session.
  await NotificationService.instance.init();

  runApp(const TasklyApp());
}

// Convenience getter for the Supabase client used throughout the app.
final supabase = Supabase.instance.client;

class TasklyApp extends StatelessWidget {
  const TasklyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskly',
      debugShowCheckedModeBanner: false,
      // All styling lives in app_theme.dart so the whole app shares one
      // consistent look (brand colors, cards, buttons, fields).
      theme: buildTheme(),
      // Every launch starts on the branded splash; after a moment it hands
      // off to the AuthGate (login when logged out, teams when logged in).
      home: const SplashScreen(next: AuthGate()),
    );
  }
}

// AuthGate decides what to show based on the current auth session.
// It listens to Supabase's auth state stream so the UI updates automatically
// when the user logs in or out (including via the email confirmation link).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Fires whenever the auth session changes (sign in, sign out, refresh).
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Read the current session directly; it's already loaded after init.
        final session = supabase.auth.currentSession;

        // No session -> show the login screen (which links to signup).
        if (session == null) {
          return const LoginScreen();
        }

        // Session exists -> show the user's teams; each team routes by the
        // user's role within it.
        return const TeamsScreen();
      },
    );
  }
}
