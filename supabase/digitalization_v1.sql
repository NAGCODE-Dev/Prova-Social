create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  object_key text not null unique check (char_length(object_key) between 10 and 500),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (
    mime_type in ('image/webp', 'image/svg+xml', 'image/png', 'image/jpeg')
  ),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  width integer check (width is null or width between 1 and 12000),
  height integer check (height is null or height between 1 and 12000),
  created_at timestamptz not null default now(),
  unique (owner_id, sha256)
);

create table if not exists public.exam_media (
  exam_id uuid not null references public.exams(id) on delete cascade,
  asset_id uuid not null references public.media_assets(id) on delete cascade,
  question_position integer not null check (question_position > 0),
  role text not null default 'question_figure'
    check (role in ('question_figure', 'option_figure', 'explanation_figure')),
  alt_text text not null default '' check (char_length(alt_text) <= 500),
  created_at timestamptz not null default now(),
  primary key (exam_id, asset_id, question_position, role)
);

create index if not exists exam_media_asset_id_idx
  on public.exam_media(asset_id);

alter table public.media_assets enable row level security;
alter table public.exam_media enable row level security;

drop policy if exists media_assets_read on public.media_assets;
drop policy if exists media_assets_insert on public.media_assets;
drop policy if exists media_assets_delete on public.media_assets;
drop policy if exists exam_media_read on public.exam_media;
drop policy if exists exam_media_insert on public.exam_media;
drop policy if exists exam_media_update on public.exam_media;
drop policy if exists exam_media_delete on public.exam_media;

create policy media_assets_read on public.media_assets
for select to anon, authenticated
using (
  owner_id = (select auth.uid())
  or exists (
    select 1 from public.exam_media em
    join public.exams e on e.id = em.exam_id
    where em.asset_id = id and e.status = 'published' and e.is_public
  )
);

create policy media_assets_insert on public.media_assets
for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and (storage.foldername(object_key))[1] = (select auth.uid())::text
  and (storage.foldername(object_key))[2] = 'media'
);

create policy media_assets_delete on public.media_assets
for delete to authenticated
using (owner_id = (select auth.uid()));

create policy exam_media_read on public.exam_media
for select to anon, authenticated
using (
  exists (
    select 1 from public.exams e
    where e.id = exam_id
      and (e.author_id = (select auth.uid()) or (e.status = 'published' and e.is_public))
  )
);

create policy exam_media_insert on public.exam_media
for insert to authenticated
with check (
  exists (
    select 1 from public.exams e
    where e.id = exam_id and e.author_id = (select auth.uid())
  )
  and exists (
    select 1 from public.media_assets ma
    where ma.id = asset_id and ma.owner_id = (select auth.uid())
  )
);

create policy exam_media_delete on public.exam_media
for delete to authenticated
using (
  exists (
    select 1 from public.exams e
    where e.id = exam_id and e.author_id = (select auth.uid())
  )
);

create policy exam_media_update on public.exam_media
for update to authenticated
using (
  exists (
    select 1 from public.exams e
    where e.id = exam_id and e.author_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.exams e
    where e.id = exam_id and e.author_id = (select auth.uid())
  )
  and exists (
    select 1 from public.media_assets ma
    where ma.id = asset_id and ma.owner_id = (select auth.uid())
  )
);

grant select on public.media_assets, public.exam_media to anon, authenticated;
grant insert, delete on public.media_assets to authenticated;
grant insert, update, delete on public.exam_media to authenticated;
revoke insert, update, delete on public.media_assets, public.exam_media from anon;

-- Depois das tabelas de mídia existirem, amplia a leitura do bucket privado
-- para figuras ligadas a provas públicas.
drop policy if exists exam_content_read on storage.objects;
create policy exam_content_read on storage.objects
for select to anon, authenticated
using (
  bucket_id = 'exam-content'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.content_files cf
      join public.exams e on e.id = cf.exam_id
      where cf.object_key = name
        and cf.status = 'ready'
        and e.status = 'published'
        and e.is_public
    )
    or exists (
      select 1 from public.media_assets ma
      join public.exam_media em on em.asset_id = ma.id
      join public.exams e on e.id = em.exam_id
      where ma.object_key = name
        and e.status = 'published'
        and e.is_public
    )
  )
);
