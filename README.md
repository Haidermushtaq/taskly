# Taskly

A Flutter + Supabase task manager built on a teams model: anyone can create a
team (becoming its admin) or join one with an invite code (becoming a member).
State management is `setState` only; the backend is Supabase (auth + Postgres +
Realtime), with per-team roles enforced by Row Level Security.

## Setup

Supabase credentials are **not** committed. They are read at compile time from a
git-ignored `.env` file via `--dart-define-from-file`.

1. Clone and enter the project:
   ```
   git clone https://github.com/Haidermushtaq/taskly.git
   cd taskly
   ```
2. Create your `.env` from the template and fill in your Supabase values:
   ```
   cp .env.example .env
   ```
   `.env` holds:
   ```
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```
   The anon key is public by design; real security is Supabase Row Level Security.
3. Install dependencies:
   ```
   flutter pub get
   ```

## Supabase dashboard setup

Two features need one-time configuration in the Supabase project. The app code
is already done; without these steps those features silently do nothing.

### Notifications (Realtime on `tasks`)

Notifications are driven by Postgres change events on the `tasks` table, so
that table has to be published to Realtime — `messages` already is. Run this
once in the SQL editor:

```sql
alter publication supabase_realtime add table tasks;
```

Check it worked (the table should be listed):

```sql
select tablename from pg_publication_tables
where pubname = 'supabase_realtime';
```

No Firebase, no Edge Function and no new table is involved: the app subscribes
directly, and RLS still restricts what each user can receive.

### Google and Facebook sign-in

1. **Auth → Providers → Google**: enable it, and paste the Client ID and Client
   Secret from a Google Cloud OAuth 2.0 **Web application** credential. In the
   Google Cloud console, add Supabase's callback as an authorized redirect URI:
   `https://<your-project-ref>.supabase.co/auth/v1/callback`
2. **Auth → Providers → Facebook**: enable it, and paste the App ID and App
   Secret from a Meta app (Facebook Login product added). Use the same callback
   URL above as the Valid OAuth Redirect URI.
3. **Auth → URL Configuration → Redirect URLs**: add
   `io.supabase.taskly://login-callback/`
   so Supabase is allowed to send the user back into the app. This is the same
   deep link email confirmation already uses, so it may already be there.

## Running

You must pass the env file on every run and build, or the app throws a clear
"Missing SUPABASE_URL / SUPABASE_ANON_KEY" error at startup:

```
flutter run --dart-define-from-file=.env
```

Build a release APK:

```
flutter build apk --dart-define-from-file=.env
```

## Notifications

Task notifications are local notifications raised from Supabase Realtime
events, not Firebase push. Each signed-in user opens two filtered channels on
the `tasks` table (see `lib/services/notification_service.dart`):

| Who | Event watched | Notification |
| --- | --- | --- |
| Member | `INSERT` where `assigned_to` = me | "New task assigned to you" |
| Admin | `UPDATE` where `created_by` = me | "Task status updated" |

Because this is an in-app socket rather than push, notifications arrive while
the app is running. Delivering them with the app fully closed would require
Firebase Cloud Messaging and a server-side sender.

On first launch the app asks for notification permission (Android 13+ and
iOS). If it was denied, re-enable it in the OS settings for Taskly.
