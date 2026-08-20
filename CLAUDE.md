# Taskly - Task Manager App (Internship Evaluation Project)

Flutter + Supabase task manager built on a teams model: anyone can create a
team (becoming its admin) or join one with an invite code (becoming a
member). This project will be reviewed line by line in an interview, so code
must be simple, readable, and explainable.

## Hard Rules
- State management: setState ONLY. No Riverpod, BLoC, GetX, Provider.
- Keep code simple. Prefer readable over clever. No unnecessary abstractions.
- Backend is Supabase only (supabase_flutter package). No custom server.
- Roles (admin/member) are PER TEAM, stored in team_members, and enforced by
  RLS in the database. Flutter only routes UI based on role, never treat UI
  checks as security.
- Every file must start with a short comment block explaining what the file
  does and how it fits in the app flow.
- After completing each task I give you, explain the flow of the code you
  wrote in plain language.
- Do not build ahead. Only do the chunk I ask for.

## Folder Structure
lib/
  main.dart            # Supabase init + auth gate
  models/              # plain Dart classes (Profile, Team, TeamMember, Task, Message)
  services/            # auth_service, team_service, task_service, chat_service,
                       #   notification_service
  screens/
    auth/              # login_screen.dart, signup_screen.dart, forgot_password_screen.dart
    teams/             # teams_screen.dart (home: list/create/join teams)
    admin/             # team dashboard, create/assign task, all tasks,
                       #   team_summary_screen.dart (per-employee stats)
    employee/          # my_tasks_screen.dart (member view of a team)
    chat/              # chat_screen.dart (group + DM), members_screen.dart
    profile/           # profile_screen.dart (my info, teams, tasks overview),
                       #   settings_screen.dart (edit name, change password)
  widgets/             # shared widgets (task_card, empty_state, logout_button,
                       #   overdue_banner, social_sign_in_buttons,
                       #   task_filter_bar)

## App Flow
1. App starts -> Supabase.initialize in main.dart -> branded SplashScreen
   (logo + name on the brand gradient, ~2.5s) on every launch
2. Splash hands off to the auth gate: no session -> LoginScreen. Session
   exists -> TeamsScreen. Never straight to a screen without the splash
3. TeamsScreen: lists my teams with my role in each. Buttons to create a
   team (I become admin) or join by invite code (I become member)
4. Tap a team -> route by my role in THAT team:
   admin -> AdminDashboard, member -> MyTasksScreen
5. Member: sees only tasks assigned to them in that team, can update task
   status (pending -> in_progress -> done)
6. Admin: sees invite code (to share), task counts, creates tasks with a
   priority and an optional deadline (due_at), assigns to any team member,
   sees all team tasks, deletes tasks, opens the team summary
7. Both roles, from a team's app bar: team group chat and the members list;
   tap a member to open a private (direct) chat. Chat is live via Supabase
   Realtime streams (StreamBuilder)
8. Profile screen (person icon on teams screen): my name + email, all my
   teams with roles, all my tasks across teams grouped by status, with
   deadlines and overdue markers. The pencil in its app bar opens
   SettingsScreen: edit display name (writes profiles.name) and change
   password (updateUser on the live session — the in-app change, separate
   from the emailed-code forgot-password flow)
9. Logout from the teams screen app bar
10. Notifications (in-app, no Firebase): notification_service.dart subscribes
    to Postgres change events on `tasks` over Supabase Realtime while a
    session exists. Members get "New task assigned to you" on INSERT where
    assigned_to = me; admins get "Task status updated" on UPDATE where
    created_by = me. Drawn with flutter_local_notifications. Requires
    `alter publication supabase_realtime add table tasks;`
11. Overdue visibility: OverdueBanner (a red "N tasks are past their deadline"
    strip) sits at the top of both the admin dashboard and the member task
    list, on top of the per-card red deadline line
12. Priority: every task is low / medium / high (default medium), chosen by
    the admin on the create-task form and shown as a flag chip on the task
    card, so it is visible on both the admin and member lists
13. Search & filter: TaskFilterBar sits above both task lists — free text over
    title + description, plus status and priority dropdowns, plus an assignee
    dropdown on the admin list only. Filtering is done in memory over the
    already-fetched list (TaskFilter.apply), not with new queries
14. Admin summary (TeamSummaryScreen, "Team summary" on the admin dashboard):
    team-wide completed vs open with a progress bar and status counts, then
    one card per team member with their pending / in progress / done /
    overdue counts. All counted in memory from the team's task list

## Auth Details
- Signup: supabase.auth.signUp with email + password, pass name in user
  metadata (a DB trigger auto-creates the profile row). Validation: name
  required, valid email shape, password >= 6 chars
- Email confirmation is ON. The confirmation link deep-links back into the
  app (io.supabase.taskly://login-callback/, registered in AndroidManifest
  and passed as emailRedirectTo). The redirect URL must be allowed in
  Supabase dashboard -> Auth -> URL Configuration
- Login: signInWithPassword
- Social sign-in: Google and Facebook via signInWithOAuth, offered on BOTH the
  login and signup screens through the shared SocialSignInButtons widget
  (a provider login doubles as a signup — Supabase creates the user on first
  use and the handle_new_user trigger reads `name` from the provider metadata).
  Redirects to the same io.supabase.taskly://login-callback/ deep link, which
  must be listed in Supabase -> Auth -> URL Configuration. Provider client
  IDs/secrets are configured in Supabase -> Auth -> Providers
- Session is persisted automatically by supabase_flutter
- Forgot password (OTP recovery, no deep links): "Forgot password?" link on
  the login screen opens forgot_password_screen.dart, one setState screen with
  three steps: (1) email -> resetPasswordForEmail (no redirectTo, so Supabase
  emails a numeric code, not a magic link; code length is the project's Auth
  OTP-length setting, 6-10 digits, so the field accepts any of them);
  (2) code -> verifyOTP with
  OtpType.recovery, which establishes a recovery session; (3) new password +
  confirm -> updateUser(password). On success the screen pops; the recovery
  session already exists, so the AuthGate underneath has routed into the app.
  Requires the recovery email template to include {{ .Token }} so the code
  shows. Auth calls live in auth_service.dart

## Database Schema (already created in Supabase, do NOT recreate)

### profiles (identity only; no global role)
- id uuid, primary key, references auth.users(id)
- name text
- created_at timestamptz
- Trigger on_auth_user_created -> handle_new_user() creates this row from
  signup metadata. The function is SECURITY DEFINER with pinned search_path
  and schema-qualified table names (required: auth service's role has a
  different search_path)

### teams
- id uuid, primary key, default gen_random_uuid()
- name text, not null
- invite_code text, unique, default 8-char random hex
- created_by uuid -> profiles(id)
- created_at timestamptz

### team_members (who is in which team, with per-team role)
- team_id uuid -> teams(id) on delete cascade
- user_id uuid -> profiles(id) on delete cascade
- role text: 'admin' | 'member', default 'member'
- created_at timestamptz
- primary key (team_id, user_id)

### tasks
- id uuid, primary key, default gen_random_uuid()
- title text, not null
- description text
- assigned_to uuid -> profiles(id)
- created_by uuid -> profiles(id)
- team_id uuid -> teams(id) on delete cascade
- status text: 'pending' | 'in_progress' | 'done', default 'pending'
- priority text: 'low' | 'medium' | 'high', default 'medium', not null
  (added after the first schema; run once in the SQL editor:
   `alter table tasks add column if not exists priority text not null
    default 'medium' check (priority in ('low','medium','high'));`)
- due_at timestamptz (optional deadline; overdue = past due and not done)
- created_at timestamptz

Both `tasks` and `messages` must be in the supabase_realtime publication:
`messages` for the live chat streams, `tasks` for the notification listeners.

### messages (chat; in supabase_realtime publication for live streams)
- id uuid, primary key, default gen_random_uuid()
- team_id uuid -> teams(id) on delete cascade (every message is in a team)
- sender_id uuid -> profiles(id)
- recipient_id uuid -> profiles(id), NULL = team group message, set = DM
- content text, not null
- created_at timestamptz

### RPC functions (the only way to create/join teams)
- create_team(team_name): inserts team + creator as admin. SECURITY DEFINER
- join_team(code): validates invite code, inserts caller as member

### RLS (already enabled, for your awareness when writing queries)
- Helpers: is_team_member(team_id), is_team_admin(team_id) — SECURITY
  DEFINER, pinned search_path
- profiles: any authenticated user can select; users update own row only
- teams: select if member. No direct insert/update/delete (RPCs only)
- team_members: select rows of teams you belong to. No direct writes
- tasks select: assigned_to = auth.uid() OR is_team_admin(team_id)
- tasks insert: is_team_admin(team_id) and created_by = auth.uid()
- tasks update: assignee or team admin
- tasks delete: team admin only
- messages select: team member AND (group message OR my own DM)
- messages insert: sender is me, I'm in the team, DM recipient must be a
  member of the same team (helper: is_user_team_member(team, user))

## Supabase Connection
- URL and anon key go in main.dart Supabase.initialize
- Anon key is public by design; RLS is the security layer

## UI Guidelines
- Material 3 with colorSchemeSeed (indigo), clean and minimal, no animations
- Loading spinners during async calls, SnackBar for errors, empty states via
  the shared EmptyState widget, error states with a Retry button
- Status colors everywhere: pending = orange, in_progress = blue, done = green
- Task card: title, description, colored status chip; member view gets a
  "move to next stage" button, admin view gets a delete button
- Admin dashboard: invite code card (with copy), 2x2 colored count grid,
  manage-tasks button
