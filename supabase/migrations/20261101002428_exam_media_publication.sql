-- Versioned schema for question media. Applied remotely as migration
-- 20261101002428_exam_media_publication.
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  object_key text not null unique check (char_length(object_key) between 10 and 500),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check (mime_type in ('image/webp','image/svg+xml','image/png','image/jpeg')),
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
    check (role in ('question_figure','option_figure','explanation_figure')),
  alt_text text not null default '' check (char_length(alt_text) <= 500),
  created_at timestamptz not null default now(),
  primary key (exam_id, asset_id, question_position, role)
);
alter table public.exam_media add column if not exists question_id uuid
  references public.questions(id) on delete cascade;
create index if not exists exam_media_asset_id_idx on public.exam_media(asset_id);
create index if not exists exam_media_question_id_idx on public.exam_media(question_id)
  where question_id is not null;

create or replace function public.set_exam_media_question_id()
returns trigger language plpgsql set search_path = pg_catalog as $$
declare v_question_id uuid;
begin
  select q.id into v_question_id from public.questions q
   where q.exam_id = new.exam_id and q.position = new.question_position;
  if v_question_id is null then
    raise exception 'question position does not belong to exam' using errcode = '23503';
  end if;
  if new.question_id is not null and new.question_id <> v_question_id then
    raise exception 'question does not match exam position' using errcode = '23514';
  end if;
  new.question_id := v_question_id;
  return new;
end;
$$;
drop trigger if exists exam_media_set_question_id on public.exam_media;
create trigger exam_media_set_question_id before insert or update of exam_id, question_position, question_id
on public.exam_media for each row execute function public.set_exam_media_question_id();
update public.exam_media em set question_id = q.id
from public.questions q where q.exam_id = em.exam_id
and q.position = em.question_position and em.question_id is distinct from q.id;

alter table public.media_assets enable row level security;
alter table public.exam_media enable row level security;
drop policy if exists media_assets_read on public.media_assets;
create policy media_assets_read on public.media_assets for select to anon, authenticated
using (owner_id = (select auth.uid()) or exists (
  select 1 from public.exam_media em join public.exams e on e.id = em.exam_id
  where em.asset_id = media_assets.id and e.status = 'published' and e.is_public
));
drop policy if exists media_assets_insert on public.media_assets;
create policy media_assets_insert on public.media_assets for insert to authenticated
with check (owner_id = (select auth.uid())
  and split_part(object_key, '/', 1) = (select auth.uid())::text
  and split_part(object_key, '/', 2) = 'media');
drop policy if exists media_assets_delete on public.media_assets;
create policy media_assets_delete on public.media_assets for delete to authenticated
using (owner_id = (select auth.uid()));
drop policy if exists exam_media_read on public.exam_media;
create policy exam_media_read on public.exam_media for select to anon, authenticated
using (exists (select 1 from public.exams e where e.id = exam_media.exam_id
  and (e.author_id = (select auth.uid()) or (e.status = 'published' and e.is_public))));
drop policy if exists exam_media_insert on public.exam_media;
create policy exam_media_insert on public.exam_media for insert to authenticated
with check (exists (select 1 from public.exams e where e.id = exam_media.exam_id
  and e.author_id = (select auth.uid())) and exists (
  select 1 from public.media_assets ma where ma.id = exam_media.asset_id
  and ma.owner_id = (select auth.uid())));
drop policy if exists exam_media_delete on public.exam_media;
create policy exam_media_delete on public.exam_media for delete to authenticated
using (exists (select 1 from public.exams e where e.id = exam_media.exam_id
  and e.author_id = (select auth.uid())));
drop policy if exists exam_media_update on public.exam_media;
create policy exam_media_update on public.exam_media for update to authenticated
using (exists (select 1 from public.exams e where e.id = exam_media.exam_id
  and e.author_id = (select auth.uid())))
with check (exists (select 1 from public.exams e where e.id = exam_media.exam_id
  and e.author_id = (select auth.uid())) and exists (
  select 1 from public.media_assets ma where ma.id = exam_media.asset_id
  and ma.owner_id = (select auth.uid())));
grant select on public.media_assets, public.exam_media to anon, authenticated;
grant insert, delete on public.media_assets to authenticated;
grant insert, update, delete on public.exam_media to authenticated;
revoke insert, update, delete on public.media_assets, public.exam_media from anon;

create or replace function public.publish_exam_with_media(
  p_title text, p_category text, p_source text, p_source_type text,
  p_year integer, p_duration_minutes integer, p_questions jsonb,
  p_source_url text, p_media jsonb
) returns uuid language plpgsql security definer set search_path = pg_catalog as $$
declare
  v_exam_id uuid;
  v_item jsonb;
  v_count integer := 0;
  v_asset_id uuid;
  v_position integer;
  v_role text;
  v_alt text;
  v_source_url text := nullif(btrim(p_source_url), '');
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_media is null or jsonb_typeof(p_media) is distinct from 'array' then
    raise exception 'invalid media list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_media) > 900 then
    raise exception 'invalid media list' using errcode = '22023';
  end if;
  if octet_length(p_media::text) > 524288 then
    raise exception 'media manifest too large' using errcode = '22023';
  end if;
  if v_source_url is not null and (char_length(v_source_url) not between 10 and 500
     or v_source_url !~ '^https://[^[:space:]/?#]+([/?#][^[:space:]]*)?$'
     or split_part(split_part(v_source_url, '://', 2), '/', 1) like '%@%') then
    raise exception 'invalid source URL' using errcode = '22023';
  end if;
  for v_item in select value from jsonb_array_elements(p_media) loop
    v_count := v_count + 1;
    if (select count(*) from jsonb_object_keys(v_item)) <> 4
       or not (v_item ?& array['asset_id','question_position','role','alt_text']) then
      raise exception 'invalid media entry' using errcode = '22023';
    end if;
    begin
      if coalesce(v_item->>'question_position', '') !~ '^[1-9][0-9]*$' then
        raise exception 'invalid question position';
      end if;
      v_asset_id := (v_item->>'asset_id')::uuid;
      v_position := (v_item->>'question_position')::integer;
    exception when others then raise exception 'invalid media reference' using errcode = '22023';
    end;
    v_role := v_item->>'role'; v_alt := coalesce(v_item->>'alt_text', '');
    if v_position < 1 or v_position > jsonb_array_length(p_questions)
       or v_role is null
       or v_role not in ('question_figure','option_figure','explanation_figure')
       or char_length(v_alt) > 500
       or not exists (select 1 from public.media_assets ma
         where ma.id = v_asset_id and ma.owner_id = auth.uid()) then
      raise exception 'invalid or unauthorized media reference' using errcode = '22023';
    end if;
  end loop;
  v_exam_id := public.publish_exam(p_title,p_category,p_source,p_source_type,
    p_year,p_duration_minutes,p_questions);
  if v_source_url is not null then
    update public.exams set source_url = v_source_url where id = v_exam_id and author_id = auth.uid();
  end if;
  insert into public.exam_media(exam_id, asset_id, question_position, question_id, role, alt_text)
  select v_exam_id, (m.value->>'asset_id')::uuid, (m.value->>'question_position')::integer,
    q.id, m.value->>'role', coalesce(m.value->>'alt_text','')
  from jsonb_array_elements(p_media) m(value)
  join public.questions q on q.exam_id = v_exam_id
    and q.position = (m.value->>'question_position')::integer;
  if (select count(*) from public.exam_media em where em.exam_id = v_exam_id) < v_count then
    raise exception 'media/question association failed' using errcode = '23503';
  end if;
  return v_exam_id;
end;
$$;
alter function public.publish_exam_with_media(text,text,text,text,integer,integer,jsonb,text,jsonb) owner to postgres;
alter function public.publish_exam_with_media(text,text,text,text,integer,integer,jsonb,text,jsonb)
  set search_path = pg_catalog, auth;
revoke all on function public.publish_exam_with_media(text,text,text,text,integer,integer,jsonb,text,jsonb) from public, anon, authenticated;
grant execute on function public.publish_exam_with_media(text,text,text,text,integer,integer,jsonb,text,jsonb) to authenticated;

-- The existing definer RPCs resolve auth.uid() at execution time while
-- restricting search_path to pg_catalog. Include the trusted auth schema.
alter function public.publish_exam(text,text,text,text,integer,integer,jsonb)
  set search_path = pg_catalog, auth;
alter function public.publish_exam_with_source_url(text,text,text,text,integer,integer,jsonb,text)
  set search_path = pg_catalog, auth;

-- Add media access without replacing package access policies.
do $$ begin
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists exam_media_storage_delete on storage.objects';
    execute $policy$create policy exam_media_storage_delete on storage.objects for delete to authenticated
      using (bucket_id = 'exam-content'
        and split_part(name, '/', 1) = (select auth.uid())::text
        and split_part(name, '/', 2) = 'media')$policy$;
    execute 'drop policy if exists exam_media_storage_insert on storage.objects';
    execute $policy$create policy exam_media_storage_insert on storage.objects for insert to authenticated
      with check (bucket_id = 'exam-content'
        and split_part(name, '/', 1) = (select auth.uid())::text
        and split_part(name, '/', 2) = 'media')$policy$;
    execute 'drop policy if exists exam_media_storage_read on storage.objects';
    execute $policy$create policy exam_media_storage_read on storage.objects for select to anon, authenticated
      using (bucket_id = 'exam-content' and exists (
        select 1 from public.media_assets ma join public.exam_media em on em.asset_id = ma.id
        join public.exams e on e.id = em.exam_id where ma.object_key = name
        and e.status = 'published' and e.is_public))$policy$;
  end if;
  if to_regclass('storage.buckets') is not null then
    execute $bucket$insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
      values ('exam-content', 'exam-content', false, 26214400,
        array['application/gzip','application/octet-stream','image/webp','image/svg+xml','image/png','image/jpeg'])
      on conflict (id) do nothing$bucket$;
  end if;
end $$;
notify pgrst, 'reload schema';
