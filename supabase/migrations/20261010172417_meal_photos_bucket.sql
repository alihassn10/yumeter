-- Private storage for meal photos, one folder per user.
--
-- Objects live at `<user id>/<meal id>.<ext>`. The first path segment is what
-- the policies check, so a user can only ever reach their own folder. Nothing
-- is public: the app and the analyze-meal function read photos with the
-- user's own session.

-- The app compresses before upload, so 5 MB is headroom rather than a target.
-- HEIC is allowed because iOS camera output arrives in that format.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'meal-photos',
  'meal-photos',
  false,
  5 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
);

create policy "Users can view their own meal photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can upload their own meal photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Needed alongside select and insert for upsert, i.e. retaking a photo.
create policy "Users can replace their own meal photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users can delete their own meal photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- The object path inside meal-photos, or null for a meal logged without one.
-- The check keeps a meal from pointing into another user's folder.
alter table public.meals
  add column photo_path text
    check (photo_path like user_id::text || '/%');
