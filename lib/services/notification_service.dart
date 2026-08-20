// services/notification_service.dart
// Turns database changes into phone notifications, with no extra backend.
//
// Two pieces work together:
//   1. flutter_local_notifications — actually draws the notification on the
//      phone (and asks the user for permission the first time).
//   2. Supabase Realtime — the app opens a live socket to the `tasks` table
//      and Postgres pushes row changes down it as they happen.
//
// We listen on two filtered channels, so each user only receives the changes
// that concern them:
//   - INSERT where assigned_to = me  -> "a task was assigned to you" (member)
//   - UPDATE where created_by  = me  -> "a task you created moved on" (admin)
// The filters run on the server and RLS still applies, so nobody can listen
// to another team's tasks.
//
// Started/stopped automatically from the auth state: the listener turns on
// when a session appears (login) and off when it goes away (logout), so it
// only ever runs for a signed-in user. main.dart just calls init() once.
//
// Note this is an in-app listener, not Firebase push: notifications arrive
// while the app is running. That keeps the whole feature inside Supabase,
// which is the backend rule for this project.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class NotificationService {
  // One shared instance for the whole app; main.dart initializes it and the
  // auth listener inside does the rest.
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final SupabaseClient _client = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // The two live subscriptions. Null while logged out.
  RealtimeChannel? _assignedChannel;
  RealtimeChannel? _statusChannel;

  // Android needs a "channel" (a named category the user can mute in system
  // settings). We use a single one for every task notification.
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'taskly_tasks',
    'Task updates',
    channelDescription: 'New tasks assigned to you and status changes.',
    importance: Importance.high,
    priority: Priority.high,
  );

  // Set up the notification plugin, ask for permission, then start watching
  // the auth state so the realtime listeners follow login/logout.
  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Reuses the app launcher icon as the notification icon.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // On iOS the plugin asks for alert/sound/badge permission here.
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Android 13+ also needs a runtime permission prompt.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Follow the session: listen while logged in, stop when logged out.
    _client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        _stopListening();
      } else {
        _startListening();
      }
    });

    // If a session was restored from storage before this ran, start now.
    if (_client.auth.currentSession != null) _startListening();
  }

  // Subscribe to the two task feeds for the logged-in user.
  void _startListening() {
    // Already listening (e.g. a token refresh re-fired the auth event).
    if (_assignedChannel != null) return;

    final myId = _client.auth.currentUser!.id;

    // Member side: a new task row assigned to me appeared.
    _assignedChannel = _client
        .channel('tasks-assigned-to-me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_to',
            value: myId,
          ),
          callback: (payload) {
            final task = payload.newRecord;
            _show(
              title: 'New task assigned to you',
              body: _assignedBody(task),
            );
          },
        )
        .subscribe();

    // Admin side: a task I created changed. The only thing that ever updates
    // a task in this app is the assignee moving it to its next stage, so the
    // new status is what we report.
    _statusChannel = _client
        .channel('tasks-i-created')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'created_by',
            value: myId,
          ),
          callback: (payload) {
            final task = payload.newRecord;
            final title = (task['title'] ?? 'A task') as String;
            final status = (task['status'] ?? '') as String;
            _show(
              title: 'Task status updated',
              body: '"$title" is now ${statusLabel(status)}.',
            );
          },
        )
        .subscribe();
  }

  // Drop both subscriptions (on logout) so the next user starts clean.
  void _stopListening() {
    if (_assignedChannel != null) {
      _client.removeChannel(_assignedChannel!);
      _assignedChannel = null;
    }
    if (_statusChannel != null) {
      _client.removeChannel(_statusChannel!);
      _statusChannel = null;
    }
  }

  // Body text for an assignment: the task title, plus the deadline when the
  // admin set one.
  String _assignedBody(Map<String, dynamic> task) {
    final title = (task['title'] ?? 'A task') as String;
    final due = task['due_at'] as String?;
    if (due == null) return title;
    return '$title - due ${formatDue(DateTime.parse(due).toLocal())}';
  }

  // Draw one notification. The id just has to be unique enough that a new
  // notification doesn't replace the previous one still on screen.
  Future<void> _show({required String title, required String body}) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
