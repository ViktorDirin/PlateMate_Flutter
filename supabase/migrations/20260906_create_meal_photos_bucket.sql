-- Migration: Create 'meal_photos' bucket and set up RLS policies for storage.objects

-- 1. Ensure 'meal_photos' bucket exists and is public
insert into storage.buckets (id, name, public)
values ('meal_photos', 'meal_photos', true)
on conflict (id) do update set public = true;

-- 2. Drop existing policies if they already exist to avoid duplicate policy conflicts
drop policy if exists "Public Access to Meal Photos" on storage.objects;
drop policy if exists "Authenticated users can upload meal photos" on storage.objects;
drop policy if exists "Authenticated users can update meal photos" on storage.objects;
drop policy if exists "Authenticated users can delete meal photos" on storage.objects;

-- 3. Public access policy (allow anyone to view/read meal photos via public URL)
create policy "Public Access to Meal Photos"
on storage.objects for select
using (bucket_id = 'meal_photos');

-- 4. Authenticated upload policy (allow logged-in users to upload meal photos)
create policy "Authenticated users can upload meal photos"
on storage.objects for insert
with check (bucket_id = 'meal_photos' and auth.role() = 'authenticated');

-- 5. Authenticated update policy (allow logged-in users to update meal photos)
create policy "Authenticated users can update meal photos"
on storage.objects for update
using (bucket_id = 'meal_photos' and auth.role() = 'authenticated');

-- 6. Authenticated delete policy (allow logged-in users to delete meal photos)
create policy "Authenticated users can delete meal photos"
on storage.objects for delete
using (bucket_id = 'meal_photos' and auth.role() = 'authenticated');
