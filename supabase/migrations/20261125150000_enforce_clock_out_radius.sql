update public.clock_out_location_override_requests
set status = 'declined',
    reviewed_at = now()
where status = 'pending';

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

  v_distance := public.clock_location_distance_meters(
    v_clock_in_location,
    p_location
  );
  if v_distance > 250 then
    raise exception
      'Clock-out is % metres from clock-in; move within 250 metres and try again.',
      round(v_distance::numeric, 1);
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
  v_distance double precision;
  v_clock_out_at timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Sign in before clocking out.';
  end if;
  if not public.is_valid_clock_location(p_location) then
    raise exception 'A valid device location is required to clock out.';
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

  v_distance := public.clock_location_distance_meters(
    v_clock_in_location,
    p_location
  );
  if v_distance > 250 then
    raise exception
      'Clock-out is % metres from clock-in; move within 250 metres and try again.',
      round(v_distance::numeric, 1);
  end if;

  update public.attendance_sessions
  set status = 'clocked_out',
      clock_out_at = v_clock_out_at,
      clock_out_location = p_location
  where id = p_attendance_id
    and employee_uid = v_uid;

  return jsonb_build_object(
    'status', 'clocked_out',
    'distance_meters', round(v_distance::numeric, 1)
  );
end;
$$;

revoke all on function public.clock_out(uuid, jsonb) from public, anon;
revoke all on function public.clock_out_with_location_check(uuid, jsonb)
  from public, anon;
revoke all on function public.clock_in(jsonb) from public, anon;
revoke all on function public.review_clock_out_location_override(uuid, text)
  from public, anon, authenticated;
grant execute on function public.clock_in(jsonb) to authenticated;
grant execute on function public.clock_out(uuid, jsonb) to authenticated;
grant execute on function public.clock_out_with_location_check(uuid, jsonb)
  to authenticated;
