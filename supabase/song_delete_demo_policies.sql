-- DEMO ONLY: these policies let any unauthenticated visitor delete any song.
-- Do not use for a public production app. Add authentication and owner-based
-- policies before enabling deletion for real users.

create policy "Demo: allow public deletion of song posts"
on public.song_posts
for delete
to anon, authenticated
using (true);

create policy "Demo: allow public deletion of song files"
on storage.objects
for delete
to anon, authenticated
using (bucket_id = 'song-uploads');
