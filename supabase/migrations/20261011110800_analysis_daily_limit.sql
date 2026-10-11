-- A per-user daily cap on photo analyses.
--
-- Every analysis spends AI quota shared by all users, so one account or a
-- script must not be able to use it all. The analyze-meal function claims a
-- use before calling the model and refunds it if the model gives nothing.
-- Days are UTC dates: the server has no reliable idea of the user's zone.
--
-- Both functions take the user id and are callable only with the server's
-- own key. Letting users call them would let anyone refund their own count
-- back to zero and ignore the limit.

create table public.analysis_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  count integer not null default 0 check (count >= 0),
  primary key (user_id, day)
);

alter table public.analysis_usage enable row level security;

-- Users may see their own usage; only the functions below change it.
create policy "Users can read their own usage"
  on public.analysis_usage for select to authenticated
  using ((select auth.uid()) = user_id);

-- Takes one analysis from today's allowance. Returns true when it fits.
-- The insert-or-increment is a single statement, so concurrent requests
-- cannot both slip past the limit.
create function public.claim_analysis(p_user uuid, daily_limit integer)
returns boolean
language plpgsql
set search_path = ''
as $$
declare
  claimed integer;
begin
  insert into public.analysis_usage as u (user_id, day, count)
  values (p_user, (now() at time zone 'utc')::date, 1)
  on conflict (user_id, day) do update
    set count = u.count + 1
    where u.count < daily_limit
  returning u.count into claimed;

  -- No row means the update's where clause failed: the limit is reached.
  return claimed is not null;
end;
$$;

-- Gives back a use when the model failed, so outages do not eat allowance.
create function public.refund_analysis(p_user uuid)
returns void
language sql
set search_path = ''
as $$
  update public.analysis_usage
  set count = count - 1
  where user_id = p_user
    and day = (now() at time zone 'utc')::date
    and count > 0;
$$;

revoke all on function public.claim_analysis(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.refund_analysis(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_analysis(uuid, integer) to service_role;
grant execute on function public.refund_analysis(uuid) to service_role;
