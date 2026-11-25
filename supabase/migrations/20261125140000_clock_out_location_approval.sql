create table if not exists public.clock_out_location_override_requests (
  id uuid primary key default gen_random_uuid(),
  attendance_id uuid not null references public.attendance_sessions(id),
  employee_uid text not null references public.employee_profiles(uid),
  employee_name text not null,
  employee_email text not null,
  requested_location jsonb not null
    check (public.is_valid_clock_location(requested_location)),
  requested_at timestamptz not null default now(),
  distance_meters double precision not null check (distance_meters > 250),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'declined')),
  reviewed_by text references public.employee_profiles(uid),
  reviewed_at timestamptz
);

create unique index if not exists clock_out_override_one_pending_per_shift
  on public.clock_out_location_override_requests(attendance_id)
  where status = 'pending';
create index if not exists clock_out_override_employee_requested_idx
  on public.clock_out_location_override_requests(employee_uid, requested_at desc);
create index if not exists clock_out_override_status_requested_idx
  on public.clock_out_location_override_requests(status, requested_at desc);

alter table public.clock_out_location_override_requests enable row level security;
drop policy if exists clock_out_location_override_requests_read
  on public.clock_out_location_override_requests;
create policy clock_out_location_override_requests_read
  on public.clock_out_location_override_requests
  for select to authenticated
  using (
    employee_uid = (select auth.jwt() ->> 'sub')
    or (select public.is_attendance_admin())
  );
revoke all on public.clock_out_location_override_requests
  from public, anon, authenticated;
grant select on public.clock_out_location_override_requests to authenticated;

create or replace function public.clock_location_distance_meters(
  p_start jsonb,
  p_end jsonb
)
returns double precision
language sql
immutable
set search_path = ''
as $$
  select 2 * 6371000.0 * asin(
    sqrt(
      least(
        1.0,
        greatest(
          0.0,
          power(
            sin(radians(
              ((p_end ->> 'latitude')::double precision
                - (p_start ->> 'latitude')::double precision) / 2
            )),
            2
          )
          + cos(radians((p_start ->> 'latitude')::double precision))
          * cos(radians((p_end ->> 'latitude')::double precision))
          * power(
            sin(radians(
              ((p_end ->> 'longitude')::double precision
                - (p_start ->> 'longitude')::double precision) / 2
            )),
            2
          )
        )
      )
    )
  );
$$;

revoke all on function public.clock_location_distance_meters(jsonb, jsonb)
  from public, anon, authenticated;

create or replace function public.clock_in(p_location jsonb)
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
  if (p_location ->> 'accuracy')::double precision > 50 then
    raise exception 'Location accuracy is too low (over 50 metres). '
      'Move outdoors and try clocking in again.';
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
  v_clock_in_location jsonb;
  v_distance double precision;
begin
  if v_uid is null then
    raise exception 'Sign in before clocking out.';
  end if;
  if not public.is_valid_clock_location(p_location) then
    raise exception 'A valid device location is required to clock out.';
  end if;
  if (p_location ->> 'accuracy')::double precision > 50 then
    raise exception 'Location accuracy is too low (over 50 metres). '
      'Move outdoors and try clocking out again.';
  end if;

  select clock_in_location into v_clock_in_location
  from public.attendance_sessions
  where id = p_attendance_id
    and employee_uid = v_uid
    and status = 'clocked_in'
    and active_break_id is null
  for update;
  if not found then
    raise exception 'No active shift found. End any break before clocking out.';
  end if;
  if exists (
    select 1
    from public.clock_out_location_override_requests
    where attendance_id = p_attendance_id
      and status = 'pending'
  ) then
    raise exception 'A clock-out location request is pending admin review.';
  end if;

  v_distance := public.clock_location_distance_meters(
    v_clock_in_location,
    p_location
  );
  if v_distance > 250 then
    raise exception 'Clock-out is more than 250 metres from clock-in. '
      'An administrator must review a location exception.';
  end if;

  update public.attendance_sessions
  set status = 'clocked_out',
      clock_out_at = now(),
      clock_out_location = p_location
  where id = p_attendance_id
    and employee_uid = v_uid;
end;
$$;

create or replace function public.clock_out_with_location_check(
  p_attendance_id uuid,
  p_location jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_clock_in_location jsonb;
  v_employee_name text;
  v_employee_email text;
  v_distance double precision;
  v_request_id uuid;
  v_pending_distance double precision;
  v_requested_at timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Sign in before clocking out.';
  end if;
  if not public.is_valid_clock_location(p_location) then
    raise exception 'A valid device location is required to clock out.';
  end if;
  if (p_location ->> 'accuracy')::double precision > 50 then
    raise exception 'Location accuracy is too low (over 50 metres). '
      'Move outdoors and try clocking out again.';
  end if;

  select clock_in_location, employee_name, employee_email
  into v_clock_in_location, v_employee_name, v_employee_email
  from public.attendance_sessions
  where id = p_attendance_id
    and employee_uid = v_uid
    and status = 'clocked_in'
    and active_break_id is null
  for update;
  if not found then
    raise exception 'No active shift found. End any break before clocking out.';
  end if;

  select id, distance_meters
  into v_request_id, v_pending_distance
  from public.clock_out_location_override_requests
  where attendance_id = p_attendance_id
    and status = 'pending';
  if v_request_id is not null then
    return jsonb_build_object(
      'status', 'approval_required',
      'request_id', v_request_id,
      'distance_meters', v_pending_distance
    );
  end if;

  v_distance := public.clock_location_distance_meters(
    v_clock_in_location,
    p_location
  );

  if v_distance <= 250 then
    update public.attendance_sessions
    set status = 'clocked_out',
        clock_out_at = v_requested_at,
        clock_out_location = p_location
    where id = p_attendance_id
      and employee_uid = v_uid;

    return jsonb_build_object(
      'status', 'clocked_out',
      'distance_meters', round(v_distance::numeric, 1)
    );
  end if;

  select id into v_request_id
  from public.clock_out_location_override_requests
  where attendance_id = p_attendance_id
    and status = 'pending';

  if v_request_id is null then
    insert into public.clock_out_location_override_requests(
      attendance_id,
      employee_uid,
      employee_name,
      employee_email,
      requested_location,
      requested_at,
      distance_meters
    )
    values (
      p_attendance_id,
      v_uid,
      v_employee_name,
      v_employee_email,
      p_location,
      v_requested_at,
      v_distance
    )
    returning id into v_request_id;
  end if;

  return jsonb_build_object(
    'status', 'approval_required',
    'request_id', v_request_id,
    'distance_meters', round(v_distance::numeric, 1)
  );
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
  if exists (
    select 1
    from public.clock_out_location_override_requests
    where attendance_id = p_attendance_id
      and status = 'pending'
  ) then
    raise exception 'A clock-out location request is pending admin review.';
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

create or replace function public.review_clock_out_location_override(
  p_request_id uuid,
  p_decision text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_request public.clock_out_location_override_requests%rowtype;
begin
  if v_uid is null or not public.is_attendance_admin() then
    raise exception 'Only an administrator can review location exceptions.';
  end if;
  if p_decision is null or p_decision not in ('approved', 'declined') then
    raise exception 'Choose approve or decline.';
  end if;

  select * into v_request
  from public.clock_out_location_override_requests
  where id = p_request_id
    and status = 'pending'
  for update;
  if not found then
    raise exception 'This location request was already reviewed.';
  end if;
  if v_request.employee_uid = v_uid then
    raise exception 'You cannot review your own location exception.';
  end if;

  if p_decision = 'approved' then
    update public.attendance_sessions
    set status = 'clocked_out',
        clock_out_at = v_request.requested_at,
        clock_out_location = v_request.requested_location
    where id = v_request.attendance_id
      and employee_uid = v_request.employee_uid
      and status = 'clocked_in'
      and active_break_id is null;
    if not found then
      raise exception 'The employee shift is no longer available to clock out.';
    end if;
  end if;

  update public.clock_out_location_override_requests
  set status = p_decision,
      reviewed_by = v_uid,
      reviewed_at = now()
  where id = p_request_id;
end;
$$;

revoke all on function public.clock_in(jsonb) from public, anon;
revoke all on function public.clock_out(uuid, jsonb) from public, anon;
revoke all on function public.clock_out_with_location_check(uuid, jsonb)
  from public, anon;
revoke all on function public.start_break(uuid) from public, anon;
revoke all on function public.review_clock_out_location_override(uuid, text)
  from public, anon;
grant execute on function public.clock_in(jsonb) to authenticated;
grant execute on function public.clock_out(uuid, jsonb) to authenticated;
grant execute on function public.clock_out_with_location_check(uuid, jsonb)
  to authenticated;
grant execute on function public.start_break(uuid) to authenticated;
grant execute on function public.review_clock_out_location_override(uuid, text)
  to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'clock_out_location_override_requests'
     ) then
    alter publication supabase_realtime
      add table public.clock_out_location_override_requests;
  end if;
end;
$$;
