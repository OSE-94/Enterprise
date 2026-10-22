create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_uid text not null references public.employee_profiles(uid),
  employee_name text not null,
  employee_email text not null,
  leave_type text not null check (length(btrim(leave_type)) between 1 and 80),
  start_date date not null,
  end_date date not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'declined')),
  admin_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by text references public.employee_profiles(uid),
  check (end_date >= start_date)
);

create index if not exists leave_requests_employee_created_idx
  on public.leave_requests(employee_uid, created_at desc);
create index if not exists leave_requests_status_created_idx
  on public.leave_requests(status, created_at desc);

alter table public.leave_requests enable row level security;
drop policy if exists leave_requests_read on public.leave_requests;
create policy leave_requests_read
  on public.leave_requests for select to authenticated
  using (
    employee_uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );
revoke all on public.leave_requests from public, anon, authenticated;
grant select on public.leave_requests to authenticated;

create or replace function public.submit_leave_request(
  p_leave_type text,
  p_start_date date,
  p_end_date date
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
    raise exception 'Sign in before submitting a leave request.';
  end if;
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'The end date must be on or after the start date.';
  end if;
  if p_leave_type is null or length(btrim(p_leave_type)) not between 1 and 80 then
    raise exception 'Choose a valid leave type.';
  end if;

  insert into public.leave_requests(
    employee_uid, employee_name, employee_email, leave_type, start_date, end_date
  )
  select uid, display_name, email, btrim(p_leave_type), p_start_date, p_end_date
  from public.employee_profiles
  where uid = v_uid
  returning id into v_id;

  if v_id is null then
    raise exception 'Your employee profile is not set up.';
  end if;
  return v_id;
end;
$$;

create or replace function public.review_leave_request(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
begin
  if v_uid is null or not public.is_attendance_admin() then
    raise exception 'Only an administrator can review leave requests.';
  end if;
  if p_status not in ('approved', 'declined') then
    raise exception 'A leave request can only be approved or declined.';
  end if;

  update public.leave_requests
  set status = p_status,
      admin_note = nullif(btrim(p_admin_note), ''),
      reviewed_at = now(),
      reviewed_by = v_uid
  where id = p_request_id
    and status = 'pending';

  if not found then
    raise exception 'Request not found or it has already been reviewed.';
  end if;
end;
$$;

revoke all on function public.submit_leave_request(text, date, date)
  from public, anon;
revoke all on function public.review_leave_request(uuid, text, text)
  from public, anon;
grant execute on function public.submit_leave_request(text, date, date)
  to authenticated;
grant execute on function public.review_leave_request(uuid, text, text)
  to authenticated;

create table if not exists public.employee_messages (
  id uuid primary key default gen_random_uuid(),
  sender_uid text not null references public.employee_profiles(uid),
  sender_name text not null,
  sender_email text not null,
  recipient_uid text references public.employee_profiles(uid),
  recipient_name text,
  recipient_email text,
  is_broadcast boolean not null default false,
  subject text not null default '',
  body text not null check (length(btrim(body)) between 1 and 5000),
  created_at timestamptz not null default now(),
  check (not is_broadcast or recipient_uid is null)
);

create index if not exists employee_messages_created_idx
  on public.employee_messages(created_at desc);
create index if not exists employee_messages_sender_idx
  on public.employee_messages(sender_uid, created_at desc);
create index if not exists employee_messages_recipient_idx
  on public.employee_messages(recipient_uid, created_at desc);

alter table public.employee_messages enable row level security;
drop policy if exists employee_messages_read on public.employee_messages;
create policy employee_messages_read
  on public.employee_messages for select to authenticated
  using (
    sender_uid = (select auth.jwt() ->> 'sub')
    or recipient_uid = (select auth.jwt() ->> 'sub')
    or is_broadcast
    or (select public.is_attendance_admin())
  );
revoke all on public.employee_messages from public, anon, authenticated;
grant select on public.employee_messages to authenticated;

create or replace function public.send_employee_message(
  p_body text,
  p_subject text default '',
  p_recipient_uid text default null,
  p_is_broadcast boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_sender_role text;
  v_sender_name text;
  v_sender_email text;
  v_recipient_name text;
  v_recipient_email text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Sign in before sending a message.';
  end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 5000 then
    raise exception 'Message must contain between 1 and 5000 characters.';
  end if;

  select role, display_name, email
  into v_sender_role, v_sender_name, v_sender_email
  from public.employee_profiles
  where uid = v_uid;
  if v_sender_role is null then
    raise exception 'Your employee profile is not set up.';
  end if;

  if p_is_broadcast and v_sender_role <> 'admin' then
    raise exception 'Only an administrator can send a team announcement.';
  end if;
  if p_is_broadcast and p_recipient_uid is not null then
    raise exception 'Team announcements cannot have an individual recipient.';
  end if;

  if p_recipient_uid is not null then
    select display_name, email
    into v_recipient_name, v_recipient_email
    from public.employee_profiles
    where uid = p_recipient_uid;
    if not found then
      raise exception 'The selected employee does not exist.';
    end if;
    if v_sender_role <> 'admin' and not exists (
      select 1 from public.employee_profiles
      where uid = p_recipient_uid and role = 'admin'
    ) then
      raise exception 'Employees can send direct messages only to an admin.';
    end if;
  elsif not p_is_broadcast and v_sender_role <> 'employee' then
    raise exception 'Choose an employee or send a team announcement.';
  end if;

  insert into public.employee_messages(
    sender_uid, sender_name, sender_email,
    recipient_uid, recipient_name, recipient_email,
    is_broadcast, subject, body
  )
  values (
    v_uid, v_sender_name, v_sender_email,
    p_recipient_uid, v_recipient_name, v_recipient_email,
    p_is_broadcast, coalesce(nullif(btrim(p_subject), ''), ''), btrim(p_body)
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.send_employee_message(text, text, text, boolean)
  from public, anon;
grant execute on function public.send_employee_message(text, text, text, boolean)
  to authenticated;

create table if not exists public.employee_compensation (
  employee_uid text primary key references public.employee_profiles(uid),
  hourly_rate numeric(10, 2) not null check (hourly_rate >= 0),
  currency char(3) not null default 'GBP'
    check (currency = 'GBP'),
  updated_at timestamptz not null default now(),
  updated_by text not null references public.employee_profiles(uid)
);

alter table public.employee_compensation enable row level security;
drop policy if exists employee_compensation_read on public.employee_compensation;
create policy employee_compensation_read
  on public.employee_compensation for select to authenticated
  using (
    employee_uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );
revoke all on public.employee_compensation from public, anon, authenticated;
grant select on public.employee_compensation to authenticated;

create or replace function public.set_employee_hourly_rate(
  p_employee_uid text,
  p_hourly_rate numeric
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
begin
  if v_uid is null or not public.is_attendance_admin() then
    raise exception 'Only an administrator can set employee pay rates.';
  end if;
  if p_hourly_rate is null or p_hourly_rate < 0 or p_hourly_rate > 100000 then
    raise exception 'Enter a valid hourly rate.';
  end if;
  if not exists (
    select 1
    from public.employee_profiles
    where uid = p_employee_uid
      and role = 'employee'
  ) then
    raise exception 'Employee profile not found.';
  end if;

  insert into public.employee_compensation(
    employee_uid, hourly_rate, currency, updated_at, updated_by
  )
  values (p_employee_uid, p_hourly_rate, 'GBP', now(), v_uid)
  on conflict (employee_uid) do update
    set hourly_rate = excluded.hourly_rate,
        currency = excluded.currency,
        updated_at = excluded.updated_at,
        updated_by = excluded.updated_by;
end;
$$;

revoke all on function public.set_employee_hourly_rate(text, numeric)
  from public, anon;
grant execute on function public.set_employee_hourly_rate(text, numeric)
  to authenticated;

create or replace function public.get_attendance_history(
  p_employee_uid text default null
)
returns table (
  attendance_id uuid,
  employee_uid text,
  employee_name text,
  employee_email text,
  status text,
  clock_in_at timestamptz,
  clock_out_at timestamptz,
  total_work_seconds bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_admin boolean;
begin
  if v_uid is null then
    raise exception 'Sign in to view attendance history.';
  end if;
  v_admin := public.is_attendance_admin();
  if p_employee_uid is not null and p_employee_uid <> v_uid and not v_admin then
    raise exception 'You can only view your own attendance history.';
  end if;

  return query
  select
    session.id,
    session.employee_uid,
    session.employee_name,
    session.employee_email,
    session.status,
    session.clock_in_at,
    session.clock_out_at,
    greatest(
      0,
      floor(
        extract(epoch from (coalesce(session.clock_out_at, now()) - session.clock_in_at))
        - coalesce(breaks.total_break_seconds, 0)
      )
    )::bigint
  from public.attendance_sessions as session
  left join lateral (
    select sum(
      extract(epoch from (coalesce(attendance_break.ended_at, now())
        - attendance_break.started_at))
    ) as total_break_seconds
    from public.attendance_breaks as attendance_break
    where attendance_break.attendance_id = session.id
  ) as breaks on true
  where (v_admin and (p_employee_uid is null or session.employee_uid = p_employee_uid))
     or (not v_admin and session.employee_uid = v_uid)
  order by session.clock_in_at desc;
end;
$$;

revoke all on function public.get_attendance_history(text) from public, anon;
grant execute on function public.get_attendance_history(text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'leave_requests'
    ) then
      alter publication supabase_realtime add table public.leave_requests;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'employee_messages'
    ) then
      alter publication supabase_realtime add table public.employee_messages;
    end if;
  end if;
end;
$$;
