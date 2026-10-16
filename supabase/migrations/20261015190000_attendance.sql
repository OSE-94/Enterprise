create table if not exists public.employee_profiles (
  uid text primary key,
  email text not null,
  display_name text not null,
  role text not null default 'employee'
    check (role in ('employee', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  employee_uid text not null references public.employee_profiles(uid),
  employee_name text not null,
  employee_email text not null,
  status text not null check (status in ('clocked_in', 'on_break', 'clocked_out')),
  clock_in_at timestamptz not null default now(),
  clock_in_location jsonb not null,
  clock_out_at timestamptz,
  clock_out_location jsonb,
  active_break_id uuid,
  active_break_started_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (status = 'clocked_out' and clock_out_at is not null)
    or (status <> 'clocked_out' and clock_out_at is null)
  ),
  check (
    (status = 'on_break'
      and active_break_id is not null
      and active_break_started_at is not null)
    or (status <> 'on_break'
      and active_break_id is null
      and active_break_started_at is null)
  )
);

create unique index if not exists attendance_one_open_shift_per_employee
  on public.attendance_sessions(employee_uid)
  where status in ('clocked_in', 'on_break');

create index if not exists attendance_sessions_clock_in_at_idx
  on public.attendance_sessions(clock_in_at desc);

create table if not exists public.attendance_breaks (
  id uuid primary key default gen_random_uuid(),
  attendance_id uuid not null
    references public.attendance_sessions(id),
  employee_uid text not null references public.employee_profiles(uid),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, attendance_id, employee_uid),
  check (ended_at is null or ended_at >= started_at)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'attendance_active_break_fk'
      and conrelid = 'public.attendance_sessions'::regclass
  ) then
    alter table public.attendance_sessions
      add constraint attendance_active_break_fk
      foreign key (active_break_id, id, employee_uid)
      references public.attendance_breaks(id, attendance_id, employee_uid)
      deferrable initially deferred;
  end if;
end;
$$;

create index if not exists attendance_breaks_session_start_idx
  on public.attendance_breaks(attendance_id, started_at);

create or replace function public.is_valid_clock_location(p_location jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    jsonb_typeof(p_location) = 'object'
    and jsonb_typeof(p_location -> 'latitude') = 'number'
    and jsonb_typeof(p_location -> 'longitude') = 'number'
    and jsonb_typeof(p_location -> 'accuracy') = 'number'
    and (p_location ->> 'latitude')::double precision between -90 and 90
    and (p_location ->> 'longitude')::double precision between -180 and 180
    and (p_location ->> 'accuracy')::double precision >= 0,
    false
  );
$$;

create or replace function public.is_attendance_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employee_profiles as profile
    where profile.uid = (select auth.jwt() ->> 'sub')
      and profile.role = 'admin'
  );
$$;

alter table public.employee_profiles enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_breaks enable row level security;

drop policy if exists employee_profiles_read on public.employee_profiles;
create policy employee_profiles_read
  on public.employee_profiles for select to authenticated
  using (
    uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );

drop policy if exists employee_profiles_create_self
  on public.employee_profiles;
create policy employee_profiles_create_self
  on public.employee_profiles for insert to authenticated
  with check (
    uid = (select auth.jwt() ->> 'sub')
    and role = 'employee'
  );

drop policy if exists attendance_sessions_read
  on public.attendance_sessions;
create policy attendance_sessions_read
  on public.attendance_sessions for select to authenticated
  using (
    employee_uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );

drop policy if exists attendance_breaks_read
  on public.attendance_breaks;
create policy attendance_breaks_read
  on public.attendance_breaks for select to authenticated
  using (
    employee_uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );

revoke all on public.employee_profiles from anon, authenticated;
revoke all on public.attendance_sessions from anon, authenticated;
revoke all on public.attendance_breaks from anon, authenticated;
grant select, insert on public.employee_profiles to authenticated;
grant select on public.attendance_sessions to authenticated;
grant select on public.attendance_breaks to authenticated;

create or replace function public.clock_in(
  p_location jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Sign in before clocking in.';
  end if;
  if not exists (
    select 1 from public.employee_profiles
    where uid = v_uid and role in ('employee', 'admin')
  ) then
    raise exception 'Your employee profile is not set up.';
  end if;
  if not public.is_valid_clock_location(p_location) then
    raise exception 'A valid device location is required to clock in.';
  end if;

  insert into public.attendance_sessions (
    employee_uid, employee_name, employee_email, status, clock_in_location
  )
  select profile.uid, profile.display_name, profile.email, 'clocked_in',
         p_location
  from public.employee_profiles as profile
  where profile.uid = v_uid
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception 'You are already clocked in.';
end;
$$;

create or replace function public.clock_out(
  p_attendance_id uuid,
  p_location jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
begin
  if v_uid is null then
    raise exception 'Sign in before clocking out.';
  end if;
  if not public.is_valid_clock_location(p_location) then
    raise exception 'A valid device location is required to clock out.';
  end if;

  update public.attendance_sessions
  set status = 'clocked_out',
      clock_out_at = now(),
      clock_out_location = p_location
  where id = p_attendance_id
    and employee_uid = v_uid
    and status = 'clocked_in'
    and active_break_id is null;

  if not found then
    raise exception 'No active shift found. End any break before clocking out.';
  end if;
end;
$$;

create or replace function public.start_break(p_attendance_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_break_id uuid;
begin
  if v_uid is null then
    raise exception 'Sign in before starting a break.';
  end if;

  perform 1 from public.attendance_sessions
  where id = p_attendance_id
    and employee_uid = v_uid
    and status = 'clocked_in'
    and active_break_id is null
  for update;

  if not found then
    raise exception 'You can only start a break while clocked in.';
  end if;

  insert into public.attendance_breaks(attendance_id, employee_uid)
  values (p_attendance_id, v_uid)
  returning id into v_break_id;

  update public.attendance_sessions
  set status = 'on_break',
      active_break_id = v_break_id,
      active_break_started_at = now()
  where id = p_attendance_id and employee_uid = v_uid;

  return v_break_id;
end;
$$;

create or replace function public.end_break(p_attendance_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_break_id uuid;
begin
  if v_uid is null then
    raise exception 'Sign in before ending a break.';
  end if;

  select active_break_id into v_break_id
  from public.attendance_sessions
  where id = p_attendance_id
    and employee_uid = v_uid
    and status = 'on_break'
  for update;

  if v_break_id is null then
    raise exception 'There is no active break to end.';
  end if;

  update public.attendance_breaks
  set ended_at = now()
  where id = v_break_id
    and attendance_id = p_attendance_id
    and employee_uid = v_uid
    and ended_at is null;

  if not found then
    raise exception 'This break is no longer active.';
  end if;

  update public.attendance_sessions
  set status = 'clocked_in',
      active_break_id = null,
      active_break_started_at = null
  where id = p_attendance_id and employee_uid = v_uid;
end;
$$;

revoke all on function public.is_valid_clock_location(jsonb) from public;
revoke all on function public.is_attendance_admin() from public;
revoke all on function public.clock_in(jsonb) from public, anon;
revoke all on function public.clock_out(uuid, jsonb) from public, anon;
revoke all on function public.start_break(uuid) from public, anon;
revoke all on function public.end_break(uuid) from public, anon;
grant execute on function public.is_attendance_admin() to authenticated;
grant execute on function public.clock_in(jsonb) to authenticated;
grant execute on function public.clock_out(uuid, jsonb) to authenticated;
grant execute on function public.start_break(uuid) to authenticated;
grant execute on function public.end_break(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'attendance_sessions'
     ) then
    alter publication supabase_realtime
      add table public.attendance_sessions;
  end if;

  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'attendance_breaks'
     ) then
    alter publication supabase_realtime
      add table public.attendance_breaks;
  end if;
end;
$$;
