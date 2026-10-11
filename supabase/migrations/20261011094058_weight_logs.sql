-- Body weight over time, one entry per user per calendar day.
--
-- The day is the key, not a generated id: logging again on the same day
-- replaces that day's weight, and two phones logging the same day converge on
-- one row instead of failing on a duplicate.

create table public.weight_logs (
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  -- The user's own calendar day, so no time zone can move an entry.
  logged_on date not null,
  weight_kg numeric(5, 1) not null check (weight_kg between 20 and 400),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, logged_on)
);

create trigger weight_logs_set_updated_at
  before update on public.weight_logs
  for each row execute function public.set_updated_at();

alter table public.weight_logs enable row level security;

create policy "Users can read their own weights"
  on public.weight_logs for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can log their own weights"
  on public.weight_logs for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can edit their own weights"
  on public.weight_logs for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own weights"
  on public.weight_logs for delete to authenticated
  using ((select auth.uid()) = user_id);
