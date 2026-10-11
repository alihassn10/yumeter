-- Daily cleanup of meal photos that no meal points to.
--
-- Orphans appear when the app is closed on the review screen before the
-- unused photo can be deleted, or when an account is deleted but removing its
-- photos fails. Storage objects cannot be deleted from SQL, so a scheduled job
-- calls the cleanup-photos Edge Function, which asks this database for the
-- orphans and removes them through the Storage API.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- The orphan check looks every photo up by path.
create index meals_photo_path_idx
  on public.meals (photo_path)
  where photo_path is not null;

-- Photos in meal-photos that are older than min_age and used by no meal.
--
-- The age margin protects photos still in flight: one being reviewed right
-- now, or one whose meal was logged offline and has not synced yet. A week
-- covers a phone that stays offline for days.
create function public.orphaned_meal_photos(
  min_age interval default interval '7 days',
  max_rows integer default 500
)
returns setof text
language sql
stable
set search_path = ''
as $$
  select o.name
  from storage.objects o
  where o.bucket_id = 'meal-photos'
    and o.created_at < now() - min_age
    and not exists (
      select 1 from public.meals m where m.photo_path = o.name
    )
  order by o.created_at
  limit max_rows;
$$;

-- Only the cleanup function, running with the server's own key, may ask.
revoke all on function public.orphaned_meal_photos(interval, integer)
  from public, anon, authenticated;
grant execute on function public.orphaned_meal_photos(interval, integer)
  to service_role;

-- Where the job sends its request comes from Vault, set once per project
-- (docs/production.md, "Scheduled cleanup"): `project_url` and
-- `publishable_key`, the same public key the app ships with. They are not
-- set here because they differ per project, and a value baked into this file
-- would point every new project's job at the first one.

-- 03:17 UTC daily, off the hour so it does not queue behind other jobs.
select cron.schedule(
  'cleanup-meal-photos',
  '17 3 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'project_url') || '/functions/v1/cleanup-photos',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', (select decrypted_secret from vault.decrypted_secrets
                 where name = 'publishable_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
