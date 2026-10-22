create table if not exists public.admin_invites (
  invite_id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz,
  redeemed_by text references public.employee_profiles(uid),
  check (
    (redeemed_at is null and redeemed_by is null)
    or (redeemed_at is not null and redeemed_by is not null)
  )
);

alter table public.admin_invites enable row level security;
revoke all on public.admin_invites from public, anon, authenticated;

create or replace function public.redeem_admin_invite(
  p_invite_id uuid,
  p_display_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt() ->> 'sub');
  v_email text := coalesce((select auth.jwt() ->> 'email'), '');
  v_display_name text := nullif(btrim(p_display_name), '');
begin
  if v_uid is null then
    raise exception 'Sign in before redeeming an admin invite.';
  end if;

  perform 1
  from public.admin_invites
  where invite_id = p_invite_id
    and redeemed_at is null
  for update;

  if not found then
    raise exception 'This admin invite ID is invalid or has already been used.';
  end if;

  insert into public.employee_profiles(uid, email, display_name, role)
  values (
    v_uid,
    v_email,
    coalesce(v_display_name, nullif(v_email, ''), 'Administrator'),
    'admin'
  )
  on conflict (uid) do update
    set email = excluded.email,
        display_name = excluded.display_name,
        role = 'admin';

  update public.admin_invites
  set redeemed_at = now(),
      redeemed_by = v_uid
  where invite_id = p_invite_id
    and redeemed_at is null;

  if not found then
    raise exception 'This admin invite ID has already been used.';
  end if;
end;
$$;

revoke all on function public.redeem_admin_invite(uuid, text)
  from public, anon;
grant execute on function public.redeem_admin_invite(uuid, text)
  to authenticated;
