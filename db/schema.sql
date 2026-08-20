-- =============================================================================
-- Taskly — full database schema
-- =============================================================================
-- Postgres / Supabase. Covers tables, helper functions, RPC functions, the
-- signup trigger, Row Level Security policies, and Realtime publication.
--
-- This file is written to be idempotent where practical, so it can be run
-- against a fresh project to recreate the database.
--
-- NOTE ON PROVENANCE: this schema is maintained by hand alongside the app.
-- For an authoritative dump of the live database, use the Supabase CLI:
--     supabase link --project-ref <project-ref>
--     supabase db dump -f db/schema.dump.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. TABLES
-- -----------------------------------------------------------------------------

-- profiles — identity only. No global role; roles are per team.
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text,
  created_at timestamptz not null default now()
);

-- teams
create table if not exists public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  invite_code text unique not null default encode(gen_random_bytes(4), 'hex'),
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

-- team_members — who is in which team, with the per-team role.
create table if not exists public.team_members (
  team_id    uuid not null references public.teams(id)    on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('admin','member')),
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- tasks
create table if not exists public.tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  assigned_to uuid references public.profiles(id),
  created_by  uuid references public.profiles(id),
  team_id     uuid references public.teams(id) on delete cascade,
  status      text not null default 'pending'
                check (status in ('pending','in_progress','done')),
  priority    text not null default 'medium'
                check (priority in ('low','medium','high')),
  due_at      timestamptz,
  created_at  timestamptz not null default now()
);

-- messages — chat. recipient_id NULL = team group message, set = direct message.
create table if not exists public.messages (
  id           uuid primary key default gen_random_uuid(),
  team_id      uuid not null references public.teams(id)    on delete cascade,
  sender_id    uuid references public.profiles(id),
  recipient_id uuid references public.profiles(id),
  content      text not null,
  created_at   timestamptz not null default now()
);

-- Helpful indexes for the app's actual query patterns.
create index if not exists tasks_team_idx        on public.tasks(team_id);
create index if not exists tasks_assigned_idx    on public.tasks(assigned_to);
create index if not exists messages_team_idx     on public.messages(team_id, created_at);
create index if not exists team_members_user_idx on public.team_members(user_id);


-- -----------------------------------------------------------------------------
-- 2. SIGNUP TRIGGER
-- -----------------------------------------------------------------------------
-- Creates the profiles row automatically when an auth user is created, reading
-- the display name from signup metadata. For OAuth logins the provider supplies
-- `name` in the same metadata, which is why social login doubles as signup.
--
-- SECURITY DEFINER with a pinned search_path and schema-qualified table names
-- is required: the auth service's role runs with a different search_path.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- -----------------------------------------------------------------------------
-- 3. RLS HELPER FUNCTIONS
-- -----------------------------------------------------------------------------
-- SECURITY DEFINER so they can read team_members without re-entering that
-- table's own policies (which would recurse).

create or replace function public.is_team_member(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members
    where team_id = p_team_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_team_admin(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members
    where team_id = p_team_id and user_id = auth.uid() and role = 'admin'
  );
$$;

-- Used by the messages insert policy to confirm a DM recipient is in the team.
create or replace function public.is_user_team_member(p_team_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members
    where team_id = p_team_id and user_id = p_user_id
  );
$$;


-- -----------------------------------------------------------------------------
-- 4. RPC FUNCTIONS — the only way to create or join a team
-- -----------------------------------------------------------------------------
-- team_members has no client insert policy, so a client cannot insert a team
-- and then add itself as admin. These SECURITY DEFINER functions do both
-- atomically and validate the invite code server-side.

create or replace function public.create_team(team_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_team_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.teams (name, created_by)
  values (team_name, auth.uid())
  returning id into new_team_id;

  insert into public.team_members (team_id, user_id, role)
  values (new_team_id, auth.uid(), 'admin');

  return new_team_id;
end;
$$;

create or replace function public.join_team(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_team_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select id into target_team_id
  from public.teams
  where invite_code = code;

  if target_team_id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.team_members (team_id, user_id, role)
  values (target_team_id, auth.uid(), 'member')
  on conflict (team_id, user_id) do nothing;

  return target_team_id;
end;
$$;


-- -----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------
-- RLS is the app's real access control. The Flutter client only ever asks for
-- less data than it is allowed; it never grants itself more.

alter table public.profiles     enable row level security;
alter table public.teams        enable row level security;
alter table public.team_members enable row level security;
alter table public.tasks        enable row level security;
alter table public.messages     enable row level security;

-- profiles: everyone signed in can read names; you may update only yourself.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- teams: readable by members. No direct writes — RPCs only.
drop policy if exists teams_select_member on public.teams;
create policy teams_select_member on public.teams
  for select to authenticated using (public.is_team_member(id));

-- team_members: you can read the rosters of teams you belong to. No writes.
drop policy if exists team_members_select on public.team_members;
create policy team_members_select on public.team_members
  for select to authenticated using (public.is_team_member(team_id));

-- tasks
drop policy if exists tasks_select on public.tasks;
create policy tasks_select on public.tasks
  for select to authenticated
  using (assigned_to = auth.uid() or public.is_team_admin(team_id));

drop policy if exists tasks_insert_admin on public.tasks;
create policy tasks_insert_admin on public.tasks
  for insert to authenticated
  with check (public.is_team_admin(team_id) and created_by = auth.uid());

drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks
  for update to authenticated
  using (assigned_to = auth.uid() or public.is_team_admin(team_id))
  with check (assigned_to = auth.uid() or public.is_team_admin(team_id));

drop policy if exists tasks_delete_admin on public.tasks;
create policy tasks_delete_admin on public.tasks
  for delete to authenticated
  using (public.is_team_admin(team_id));

-- messages: team members see group messages and their own DMs.
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (
    public.is_team_member(team_id)
    and (
      recipient_id is null
      or sender_id = auth.uid()
      or recipient_id = auth.uid()
    )
  );

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_team_member(team_id)
    and (
      recipient_id is null
      or public.is_user_team_member(team_id, recipient_id)
    )
  );


-- -----------------------------------------------------------------------------
-- 6. REALTIME PUBLICATION
-- -----------------------------------------------------------------------------
-- `messages` powers the live chat streams.
-- `tasks` powers the notification listeners.
-- Adding a table that is already a member raises an error, so guard it.

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
