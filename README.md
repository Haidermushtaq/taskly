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
