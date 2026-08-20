# Taskly — Project Documentation

Team-based task manager built with Flutter and Supabase.

- **Version:** 1.0.0+1
- **Platforms:** Android (primary), iOS (configured, not distributed)
- **Backend:** Supabase only — no custom server

---

## 1. Concept

Taskly is built on a **teams** model. There is no global "admin" or "employee"
account type. Instead:

- Anyone can **create a team** and automatically becomes that team's **admin**.
- Anyone can **join a team** with an 8-character invite code and becomes a
  **member**.
- A single user can be an admin in one team and a member in another at the
  same time.

Roles are stored per team in `team_members` and enforced in the database by
Row Level Security. The Flutter app only uses the role to decide which screen
to show — it is never treated as a security boundary.

---

## 2. Feature List

### 2.1 Authentication

| Feature | Detail |
|---|---|
| Sign up | Email + password, with display name. Validation: name required, valid email shape, password ≥ 6 characters |
| Email confirmation | Enabled. Confirmation link deep-links back into the app |
| Log in | Email + password |
| Google sign-in | OAuth via Supabase, offered on both login and signup screens |
| Facebook sign-in | OAuth via Supabase, same placement |
| Forgot password | 3-step in-app OTP recovery — no deep link required |
| Change password | In-app, from Settings, on the live session |
| Session persistence | Automatic; survives app restarts, token auto-refreshed |
| Logout | From the teams screen app bar |

Social sign-in doubles as sign-up: the first time a provider is used, Supabase
creates the user and a database trigger creates the matching profile row from
the provider's `name` metadata.

### 2.2 Teams

- Create a team (creator becomes admin)
- Join a team by invite code (joiner becomes member)
- Teams list showing every team the user belongs to, with their role in each
- Invite code displayed to admins, with copy-to-clipboard

### 2.3 Tasks

- Admin creates a task with title, description, assignee, **priority**, and an
  optional **deadline**
- Assignment to any member of that team
- Status flow: `pending → in_progress → done`, advanced by the assignee via a
  "move to next stage" button
- Admin can delete any task in their team
- Member sees only tasks assigned to them, in that team
- Admin sees all tasks in the team
- Priority levels: `low` / `medium` / `high` (default `medium`), shown as a
  flag chip on every task card
- Deadlines with overdue detection (past due and not done)

### 2.4 Search & Filtering

A shared filter bar sits above both the admin and member task lists:

- Free-text search across title + description
- Status dropdown
- Priority dropdown
- Assignee dropdown (admin list only)

Filtering runs **in memory** over the already-fetched list, not as new database
queries — team task lists are small, and refetching per keystroke would be
slower and noisier.

### 2.5 Chat

- Team group chat
- Private direct messages between any two members of a team
- Live updates via Supabase Realtime streams — no manual refresh
- Members list, tap a member to open a DM

### 2.6 Notifications

In-app notifications with **no Firebase and no push service**:

- Members receive "New task assigned to you" when a task is inserted with
  `assigned_to = me`
- Admins receive "Task status updated" when a task they created is updated

Delivered while the app is running, drawn with `flutter_local_notifications`.

### 2.7 Dashboards & Overviews

- **Admin dashboard:** invite code card, 2×2 status count grid, manage-tasks
  button, team summary link
- **Team summary:** team-wide completed vs open with a progress bar, plus one
  card per member showing their pending / in progress / done / overdue counts
- **Overdue banner:** red "N tasks are past their deadline" strip at the top of
  both the admin dashboard and the member task list
- **Profile screen:** name, email, all teams with roles, and all tasks across
  all teams grouped by status
- **Settings:** edit display name, change password

### 2.8 Changes since the last review

Four features were added since the last discussion. Only one of them required
a database change:

| Feature | Where it lives | Database change |
|---|---|---|
| Task priority (low/medium/high) | create-task form, task card chip, filter bar | **Yes** — new `priority` column on `tasks` |
| Search & filter by status / priority / assignee | `widgets/task_filter_bar.dart`, above both task lists | None |
| Profile & settings (edit name, change password) | `screens/profile/settings_screen.dart` | None |
| Admin summary dashboard (per-employee counts, completed vs pending) | `screens/admin/team_summary_screen.dart` | None |

Why the other three needed no schema change:

- **Search & filter** runs in memory over the already-fetched task list. It
  filters on fields that already exist — title, description, status, priority,
  assignee — so it adds no queries and no columns.
- **Profile & settings** writes the existing `profiles.name` column, already
  covered by the existing "update your own row" RLS policy. Password changes
  go through Supabase Auth (`updateUser`) and never touch the public schema.
- **Admin summary** computes every count in Dart from the team's task list.
  There is no summary table, view or counter to keep in sync.

These four files contain **zero database calls** between them — every query in
the app lives in `services/`.

Migration scripts: `db/migrations.sql`. Full schema: `db/schema.sql`.

---

## 3. Tech Stack

| Layer | Choice |
|---|---|
| UI framework | Flutter (Material 3, `colorSchemeSeed` indigo) |
| State management | `setState` only — no Riverpod / BLoC / Provider / GetX |
| Backend | Supabase (Postgres, Auth, Realtime) |
| Client library | `supabase_flutter` ^2.5.6 (resolved 2.14.0) |
| Notifications | `flutter_local_notifications` ^22.2.0 |
| Auth | Supabase Auth (GoTrue) — email/password, OAuth, OTP recovery |
| Security | Postgres Row Level Security |

Deliberately **no** state-management library. Every screen owns three fields —
`_loading`, `_error`, `_data` — loads in `initState`, and calls `setState` with
the result. Nothing is shared between screens, so a global store would add
indirection without solving a problem.

---

## 4. Architecture

### 4.1 Folder structure

```
lib/
  main.dart              Supabase init + auth gate
  app_theme.dart         single source of styling
  models/                Profile, Team, TeamMember, Task, Message
  services/              auth, team, task, chat, notification
  screens/
    auth/                login, signup, forgot_password
    teams/               teams_screen (home)
    admin/               dashboard, create task, all tasks, team summary
    employee/            my_tasks_screen
    chat/                chat_screen, members_screen
    profile/             profile_screen, settings_screen
    splash_screen.dart
  widgets/               task_card, empty_state, logout_button,
                         overdue_banner, social_sign_in_buttons,
                         task_filter_bar
```

### 4.2 Layering rule

**Every database call lives in `services/`.** There is not a single
`.from(...)`, `.rpc(...)` or `.stream(...)` call in any screen or widget.
Screens call a service method and render the result.

```
Screen  (setState: _loading / _error / _data)
   ↓
Service (auth / team / task / chat / notification)
   ↓  supabase_flutter
HTTPS → https://<project>.supabase.co/rest/v1/...
   ↓  PostgREST converts the request into SQL
Postgres → RLS policies filter rows using auth.uid()
   ↓  JSON
Model.fromMap() → typed Dart objects → setState → rebuild
```

### 4.3 Request authentication

Every request carries two headers:

- `apikey` — the anon key, identifying the project
- `Authorization: Bearer <JWT>` — the user's access token

Postgres reads the JWT claims, so `auth.uid()` inside each RLS policy returns
the calling user's id. This is the entire access-control mechanism. The anon
key is public by design and safe to ship inside the APK, because it grants no
data access on its own.

---

## 5. Startup Sequence

1. `main()` — `WidgetsFlutterBinding.ensureInitialized()`
2. Read `SUPABASE_URL` / `SUPABASE_ANON_KEY` compile-time constants; throw a
   clear `StateError` if missing
3. `Supabase.initialize(...)` — creates the client and **restores any persisted
   session from device storage**
4. `NotificationService.init()` — initializes the plugin, requests Android 13+
   notification permission, and subscribes to auth state
5. `runApp(TasklyApp)`
6. `MaterialApp` → `home: SplashScreen(next: AuthGate())`
7. Splash displays the brand for ~2.5s, then hands off
8. `AuthGate` — a `StreamBuilder` on `onAuthStateChange`:
   no session → `LoginScreen`, session → `TeamsScreen`
9. `TeamsScreen` loads the user's teams (first database read)
10. Tapping a team routes by role in **that** team: admin → `AdminDashboard`,
    member → `MyTasksScreen`

`AuthGate` re-runs on every login, logout, token refresh and OAuth deep-link
return, which is why no screen contains callback-handling code.

---

## 6. Authentication — How It Works

### 6.1 Email + password

`signUp` passes `name` in user metadata; the `on_auth_user_created` trigger
creates the `profiles` row from it. `signInWithPassword` is a single HTTPS POST
that returns a JWT. Sessions are persisted and refreshed by `supabase_flutter`.

### 6.2 Google / Facebook (OAuth)

The app itself contains **no Google or Facebook SDK and no provider secrets**.

1. `signInWithOAuth(provider, redirectTo: 'io.supabase.taskly://login-callback/')`
   opens a Chrome Custom Tab pointed at Supabase's `/auth/v1/authorize`
2. Supabase redirects to the provider's login page
3. The user picks an account on the **provider's** domain — the app never sees
   the password
4. The provider redirects back to Supabase's callback URL with an
   authorization code
5. **Server-side**, Supabase exchanges that code plus the provider Client
   Secret for the provider's tokens, reads the profile, and finds or creates
   the user
6. Supabase mints **its own** JWT and redirects to
   `io.supabase.taskly://login-callback/?code=...`
7. Android matches the custom scheme against the intent-filter in
   `AndroidManifest.xml` and hands the URI to the app
8. `supabase_flutter` completes the PKCE exchange, stores the session, and
   emits on `onAuthStateChange`; `AuthGate` swaps to `TeamsScreen`

The provider Client Secret lives only in the Supabase dashboard. Placing it in
the APK would let anyone unzip the app and impersonate the project.

### 6.3 Forgot password (OTP recovery)

Three steps in one screen, no deep links:

1. Email → `resetPasswordForEmail` with **no** `redirectTo`, so Supabase sends
   a numeric code rather than a magic link
2. Code → `verifyOTP(OtpType.recovery)`, which establishes a recovery session
3. New password + confirm → `updateUser(password)`

Requires the recovery email template to include `{{ .Token }}`. The field
accepts 6–10 digits to match whatever OTP length the project is configured for.

### 6.4 Change password (in-app)

Separate from recovery: `updateUser` on the already-authenticated session, from
the Settings screen.

---

## 7. Roles and Permissions

Roles are **per team**, stored as `team_members.role` (`admin` | `member`).

The app uses the role only to choose a screen. All enforcement is in the
database:

| Table | Rule |
|---|---|
| `profiles` | any authenticated user can select; update own row only |
| `teams` | select if member; **no** direct insert/update/delete |
| `team_members` | select rows of teams you belong to; **no** direct writes |
| `tasks` select | `assigned_to = auth.uid()` OR team admin |
| `tasks` insert | team admin, and `created_by = auth.uid()` |
| `tasks` update | assignee or team admin |
| `tasks` delete | team admin only |
| `messages` select | team member AND (group message OR my own DM) |
| `messages` insert | sender is me, I'm in the team, DM recipient in same team |

Because `team_members` has no client insert policy, creating a team is a
chicken-and-egg problem — you cannot insert the team and then insert yourself
as its admin. Both operations therefore go through `SECURITY DEFINER` database
functions:

- `create_team(team_name)` — inserts the team, generates the invite code, and
  adds the caller as admin, atomically
- `join_team(code)` — validates the invite code **server-side** and adds the
  caller as a member

This means an invite code is never trusted from the client; a bad code is
rejected inside the database.

---

## 8. Realtime

Two distinct mechanisms, both over a WebSocket to `wss://<project>.supabase.co/realtime/v1`.

**Chat** uses `.stream()`, which loads existing rows and then pushes every
insert, consumed by a `StreamBuilder`. Realtime supports only one server-side
filter, so `team_id` is filtered on the server and the group-vs-DM split is
done in Dart.

**Notifications** use raw Postgres change channels — two `RealtimeChannel`
subscriptions with server-side filters:

- INSERT where `assigned_to = me` → "New task assigned to you"
- UPDATE where `created_by = me` → "Task status updated"

The notification service subscribes to `onAuthStateChange` and starts/stops its
channels with login/logout, so it never listens for a signed-out user.

Both `tasks` and `messages` must belong to the `supabase_realtime` publication.

---

## 9. Supabase Configuration Checklist

Settings that live in the dashboard, not in code:

- **Auth → URL Configuration → Redirect URLs** must include
  `io.supabase.taskly://login-callback/`
- **Auth → Providers → Google** enabled, with Client ID + Secret from Google
  Cloud Console (OAuth client type: **Web application**, with
  `https://<project>.supabase.co/auth/v1/callback` as an authorized redirect URI)
- **Auth → Providers → Facebook** enabled, with App ID + App Secret from Meta,
  same callback URL in Valid OAuth Redirect URIs
- **Auth → Emails** — recovery template must contain `{{ .Token }}`
- Email confirmation enabled
- `tasks` and `messages` added to the `supabase_realtime` publication

While the Google consent screen is in **Testing** and the Meta app is in
**Development**, only accounts explicitly added as test users / testers can
sign in with those providers.

---

## 10. Build and Run

Credentials are supplied at compile time and are not committed.

Create `.env` from the template:

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon key>
```

Run in development:

```
flutter run --dart-define-from-file=.env
```

Build a release APK:

```
flutter build apk --release --dart-define-from-file=.env
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 11. Known Limitations

- **Release signing:** the release build is currently signed with the Flutter
  debug keystore (`android/app/build.gradle.kts` still carries the template
  TODO). The APK installs and runs, but a proper upload keystore is required
  before any Play Store distribution.
- **Notifications are in-app only:** they arrive over a Realtime socket while
  the app is running. Background/killed-state delivery would require FCM, which
  was intentionally excluded to keep the backend Supabase-only.
- **OAuth providers are in test mode:** Google's consent screen is unverified
  and Meta's app is in Development, so provider sign-in is limited to
  allowlisted accounts until verification/review.
- **Filtering is in-memory,** which is appropriate at current team sizes but
  would need server-side querying for very large task lists.
