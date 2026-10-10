-- Profiles and the meal log, each row reachable only by the user who owns it.
--
-- Enum-like columns are text holding the Dart enum's `.name`, so the app maps
-- values without a translation table. Check constraints are loose sanity
-- bounds, not a copy of the onboarding sliders; the app owns the real ranges.

-- Keeps updated_at honest without trusting the client to send it.
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- One row per account, keyed on the auth user. Only the onboarding answers are
-- stored: the nutrition plan is derived from them in the app, so a formula
-- change reaches existing users instead of leaving a stale target here.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  sex text check (sex in ('male', 'female', 'other')),
  birth_date date check (birth_date > '1900-01-01'),
  height_cm numeric(5, 1) check (height_cm between 50 and 300),
  weight_kg numeric(5, 1) check (weight_kg between 20 and 400),
  activity_level text check (
    activity_level in ('sedentary', 'light', 'moderate', 'veryActive', 'extraActive')
  ),
  goal text check (goal in ('lose', 'maintain', 'gain')),
  target_weight_kg numeric(5, 1) check (target_weight_kg between 20 and 400),
  pace_kg_per_week numeric(3, 2) not null default 0.5
    check (pace_kg_per_week between 0 and 2),
  diet_type text not null default 'balanced' check (
    diet_type in ('balanced', 'highProtein', 'lowCarb', 'keto', 'vegetarian')
  ),
  units text not null default 'metric' check (units in ('metric', 'imperial')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

-- No delete policy: a profile goes when its auth user is deleted.
create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Users can create their own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- The meal log. Ids are generated on the device (uuid v4) so an entry logged
-- offline keeps the same id once it syncs.
create table public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  logged_at timestamptz not null,
  meal_type text not null
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  name text not null check (char_length(name) between 1 and 200),
  calories integer not null check (calories between 0 and 20000),
  -- Zero when the user logged calories alone; nothing invents a macro split.
  protein_grams integer not null default 0 check (protein_grams between 0 and 2000),
  carb_grams integer not null default 0 check (carb_grams between 0 and 2000),
  fat_grams integer not null default 0 check (fat_grams between 0 and 2000),
  source text not null default 'quickAdd'
    check (source in ('photo', 'barcode', 'search', 'quickAdd')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The Today screen and history both read one user's meals newest first.
create index meals_user_id_logged_at_idx
  on public.meals (user_id, logged_at desc);

create trigger meals_set_updated_at
  before update on public.meals
  for each row execute function public.set_updated_at();

alter table public.meals enable row level security;

create policy "Users can read their own meals"
  on public.meals for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can log their own meals"
  on public.meals for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can edit their own meals"
  on public.meals for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can delete their own meals"
  on public.meals for delete to authenticated
  using ((select auth.uid()) = user_id);
