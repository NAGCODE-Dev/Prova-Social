-- Metadados de pacotes compactados armazenados fora do Supabase (Cloudflare R2).
create table if not exists public.content_files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  exam_id uuid references public.exams(id) on delete cascade,
  provider text not null default 'cloudflare_r2' check (provider in ('cloudflare_r2')),
  object_key text not null unique check (char_length(object_key) between 10 and 500),
  original_name text not null check (char_length(original_name) between 1 and 255),
  mime_type text not null check (char_length(mime_type) between 3 and 120),
  content_encoding text not null default 'gzip' check (content_encoding in ('gzip', 'identity')),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  uncompressed_bytes bigint not null check (uncompressed_bytes >= 0),
  compressed_bytes bigint not null check (compressed_bytes >= 0),
  status text not null default 'pending' check (status in ('pending', 'ready', 'blocked', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, sha256)
);

create index if not exists content_files_exam_id_idx on public.content_files(exam_id);
create index if not exists content_files_ready_hash_idx on public.content_files(sha256) where status = 'ready';

alter table public.content_files enable row level security;

create policy content_files_read on public.content_files
for select to anon, authenticated
using (
  owner_id = (select auth.uid())
  or (
    status = 'ready'
    and exam_id is not null
    and exists (
      select 1 from public.exams e
      where e.id = exam_id and e.status = 'published' and e.is_public
    )
  )
);

create policy content_files_owner_insert on public.content_files
for insert to authenticated
with check (owner_id = (select auth.uid()));

create policy content_files_owner_update on public.content_files
for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy content_files_owner_delete on public.content_files
for delete to authenticated
using (owner_id = (select auth.uid()));

grant select on public.content_files to anon, authenticated;
revoke insert, update, delete on public.content_files from anon;
grant insert, update, delete on public.content_files to authenticated;
