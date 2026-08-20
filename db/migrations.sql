-- =============================================================================
-- Taskly — database changes since the last review
-- =============================================================================
-- Full current schema: db/schema.sql
-- Every statement below is safe to re-run.
--
--
-- FEATURES DELIVERED SINCE THE LAST REVIEW, AND THEIR DATABASE IMPACT
-- -----------------------------------------------------------------------------
--
--   Feature                     Database change required
--   -------------------------   ------------------------------------------------
--   Task priority (low/med/high) YES — new `priority` column on tasks  (001)
--   Task deadlines               YES — new `due_at` column on tasks    (002)
--   Notifications                NO new table/column — only adds `tasks`
--                                to the realtime publication           (003)
--   Search & filter              NONE
--   Profile & settings screen    NONE
--   Admin summary dashboard      NONE
--   Forgot password              NONE
--
--
-- WHY FOUR OF THESE NEEDED NO SCHEMA CHANGE
-- -----------------------------------------------------------------------------
--
--   Search & filter
--       Filtering runs in memory in the Flutter app over the task list that
--       has already been fetched (TaskFilter.apply in widgets/task_filter_bar
--       .dart). Searching title/description and filtering by status, priority
--       and assignee all read fields that already exist on `tasks`. No new
--       queries and no new columns — team task lists are small, so refetching
--       on every keystroke would be slower and noisier than filtering locally.
--
--   Profile & settings screen
--       Editing the display name writes to the existing `profiles.name`
--       column, which has been there since the original schema. The existing
--       RLS policy (a user may update only their own profiles row) already
--       covers it, so no new policy was needed either.
--
--       Changing the password does not touch the public schema at all: it is
--       auth.users, managed by Supabase Auth via updateUser() on the live
--       session. This is separate from the forgot-password flow, which uses
--       an emailed OTP to establish a recovery session first.
--
--   Admin summary dashboard
--       Per-employee counts and completed-vs-pending stats are computed in
--       Dart from the team's already-fetched task list (screens/admin/
--       team_summary_screen.dart). Nothing is stored or aggregated in the
--       database — no summary table, no view, no counters to keep in sync.
--
--   Forgot password
--       Uses Supabase Auth's built-in OTP recovery. The only configuration
--       needed is that the recovery email template includes {{ .Token }} so
--       the numeric code appears in the email. No tables, columns or policies.
--
--   Verified by inspection: task_filter_bar.dart, team_summary_screen.dart,
--   settings_screen.dart and profile_screen.dart contain zero database calls
--   between them. Every query in the app lives in services/.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 001 — Task priority
-- -----------------------------------------------------------------------------
-- Every task is low / medium / high, defaulting to medium. Shown as a flag
-- chip on the task card, so it is visible on both the admin and member lists,
-- and is one of the fields the filter bar can filter on.
--
-- NOT NULL with a default means existing rows become 'medium' automatically,
-- so no backfill step is required. The CHECK constraint keeps the three valid
-- values enforced in the database rather than only in the app.

alter table public.tasks
  add column if not exists priority text not null default 'medium'
    check (priority in ('low','medium','high'));


-- -----------------------------------------------------------------------------
-- 002 — Task deadlines
-- -----------------------------------------------------------------------------
-- Optional deadline, set by the admin on the create-task form.
--
-- "Overdue" is deliberately NOT stored. It is derived in the app as
-- (due_at is in the past AND status <> 'done'), so it can never drift out of
-- sync with the clock the way a stored boolean would.

alter table public.tasks
  add column if not exists due_at timestamptz;


-- -----------------------------------------------------------------------------
-- 003 — Realtime publication (required by notifications and chat)
-- -----------------------------------------------------------------------------
-- Notifications are in-app, with no Firebase: the app subscribes to Postgres
-- change events on the existing `tasks` table over Supabase Realtime.
--   INSERT where assigned_to = me  -> "New task assigned to you"
--   UPDATE where created_by  = me  -> "Task status updated"
--
-- `messages` was added to the publication earlier, for the live chat streams.
--
-- Adding a table that is already a member of the publication raises an error,
-- so both are guarded and this block is safe to re-run.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'tasks'
  ) then
    alter publication supabase_realtime add table public.tasks;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end
$$;


-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
-- Confirm the task columns exist and have the expected defaults/constraints:
--
--   select column_name, data_type, is_nullable, column_default
--   from information_schema.columns
--   where table_schema = 'public' and table_name = 'tasks'
--   order by ordinal_position;
--
-- Confirm the CHECK constraints:
--
--   select conname, pg_get_constraintdef(oid)
--   from pg_constraint
--   where conrelid = 'public.tasks'::regclass and contype = 'c';
--
-- Confirm realtime is enabled for both tables (expect: tasks, messages):
--
--   select tablename from pg_publication_tables
--   where pubname = 'supabase_realtime';
