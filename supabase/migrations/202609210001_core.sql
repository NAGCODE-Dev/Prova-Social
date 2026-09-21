-- Prova Social core schema. Run this migration before the optional social and
-- media migrations. Every exposed table has RLS enabled.

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Estudante'
    check (char_length(display_name) between 2 and 80),
  avatar_url text check (avatar_url is null or char_length(avatar_url) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 180),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null check (char_length(category) between 2 and 80),
  source_name text not null check (char_length(source_name) between 2 and 160),
  source_type text not null default 'community'
    check (source_type in ('official', 'community', 'unverified')),
  source_url text check (source_url is null or char_length(source_url) <= 500),
  year integer check (year is null or year between 1900 and 2200),
  duration_minutes integer not null default 120
    check (duration_minutes between 1 and 1440),
  status text not null default 'draft'
    check (status in ('draft', 'processing', 'published', 'archived', 'rejected')),
  is_public boolean not null default false,
  question_count integer not null default 0 check (question_count >= 0),
  attempts_count integer not null default 0 check (attempts_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  position integer not null check (position > 0),
  topic text not null default 'Geral' check (char_length(topic) between 1 and 100),
  statement text not null check (char_length(statement) between 2 and 20000),
  options jsonb not null check (
    jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 8
  ),
  created_at timestamptz not null default now(),
  unique (exam_id, position)
);

create table if not exists private.question_keys (
  question_id uuid primary key references public.questions(id) on delete cascade,
  correct_index integer not null check (correct_index between 0 and 7)
);

-- Upgrade installations created by the early prototype.
alter table public.exams
  add column if not exists question_count integer not null default 0
    check (question_count >= 0);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'questions'
      and column_name = 'correct_index'
  ) then
    execute $move$
      insert into private.question_keys (question_id, correct_index)
      select id, correct_index from public.questions
      where correct_index is not null
      on conflict (question_id) do update
      set correct_index = excluded.correct_index
    $move$;
  end if;
end;
$$;

alter table public.questions drop column if exists correct_index;

create table if not exists public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  exam_id uuid not null references public.exams(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, exam_id)
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  exam_id uuid not null references public.exams(id) on delete cascade,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  correct_count integer not null check (correct_count >= 0),
  total_count integer not null check (total_count > 0),
  score_percent integer not null check (score_percent between 0 and 100),
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.attempt_answers (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  selected_index integer check (selected_index is null or selected_index between 0 and 7),
  is_correct boolean not null,
  marked_for_review boolean not null default false,
  primary key (attempt_id, question_id)
);

alter table public.attempts
  add column if not exists created_at timestamptz not null default now();

create index if not exists exams_catalog_idx
  on public.exams (status, is_public, created_at desc);
create index if not exists exams_category_idx on public.exams (category);
create index if not exists questions_exam_position_idx
  on public.questions (exam_id, position);
create index if not exists attempts_user_completed_idx
  on public.attempts (user_id, completed_at desc);
create index if not exists attempts_exam_idx on public.attempts (exam_id);
create unique index if not exists attempt_answers_attempt_question_uidx
  on public.attempt_answers (attempt_id, question_id);

alter table public.profiles enable row level security;
alter table public.exams enable row level security;
alter table public.questions enable row level security;
alter table public.favorites enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;

drop policy if exists profiles_public_read on public.profiles;
create policy profiles_public_read on public.profiles
  for select to anon, authenticated using (true);
drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists exams_public_read on public.exams;
create policy exams_public_read on public.exams
  for select to anon, authenticated
  using ((status = 'published' and is_public) or author_id = (select auth.uid()));
drop policy if exists exams_owner_insert on public.exams;
create policy exams_owner_insert on public.exams
  for insert to authenticated
  with check (author_id = (select auth.uid()));
drop policy if exists exams_owner_update on public.exams;
create policy exams_owner_update on public.exams
  for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));
drop policy if exists exams_owner_delete on public.exams;
create policy exams_owner_delete on public.exams
  for delete to authenticated using (author_id = (select auth.uid()));

drop policy if exists questions_visible_exam_read on public.questions;
create policy questions_visible_exam_read on public.questions
  for select to anon, authenticated using (
    exists (
      select 1 from public.exams e
      where e.id = exam_id
        and ((e.status = 'published' and e.is_public)
          or e.author_id = (select auth.uid()))
    )
  );
drop policy if exists questions_owner_insert on public.questions;
create policy questions_owner_insert on public.questions
  for insert to authenticated with check (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  );
drop policy if exists questions_owner_update on public.questions;
create policy questions_owner_update on public.questions
  for update to authenticated using (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  ) with check (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  );
drop policy if exists questions_owner_delete on public.questions;
create policy questions_owner_delete on public.questions
  for delete to authenticated using (
    exists (
      select 1 from public.exams e
      where e.id = exam_id and e.author_id = (select auth.uid())
    )
  );

drop policy if exists favorites_owner_all on public.favorites;
create policy favorites_owner_all on public.favorites
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
drop policy if exists attempts_owner_read on public.attempts;
create policy attempts_owner_read on public.attempts
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists attempt_answers_owner_read on public.attempt_answers;
create policy attempt_answers_owner_read on public.attempt_answers
  for select to authenticated using (
    exists (
      select 1 from public.attempts a
      where a.id = attempt_id and a.user_id = (select auth.uid())
    )
  );

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      'Estudante'
    ),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of raw_user_meta_data on auth.users
  for each row execute function public.handle_new_user();

-- Inserts the complete exam in one database transaction. Answer keys are kept
-- outside the exposed public schema.
create or replace function public.publish_exam(
  p_title text,
  p_category text,
  p_source text,
  p_source_type text,
  p_year integer,
  p_duration_minutes integer,
  p_questions jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_exam_id uuid;
  v_item jsonb;
  v_question_id uuid;
  v_position integer := 0;
  v_correct integer;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if jsonb_typeof(p_questions) <> 'array'
     or jsonb_array_length(p_questions) = 0
     or jsonb_array_length(p_questions) > 300 then
    raise exception 'invalid question list';
  end if;

  insert into public.exams (
    author_id, title, description, category, source_name, source_type,
    year, duration_minutes, status, is_public, question_count
  ) values (
    v_user, trim(p_title), 'Prova revisada e publicada pela comunidade.',
    trim(p_category), trim(p_source), p_source_type, p_year,
    p_duration_minutes, 'draft', false, jsonb_array_length(p_questions)
  ) returning id into v_exam_id;

  for v_item in select value from jsonb_array_elements(p_questions)
  loop
    v_position := v_position + 1;
    v_correct := (v_item ->> 'correct_index')::integer;
    if jsonb_typeof(v_item -> 'options') <> 'array'
       or jsonb_array_length(v_item -> 'options') < 2
       or v_correct < 0
       or v_correct >= jsonb_array_length(v_item -> 'options') then
      raise exception 'invalid question at position %', v_position;
    end if;
    insert into public.questions (
      exam_id, position, topic, statement, options
    ) values (
      v_exam_id,
      v_position,
      coalesce(nullif(trim(v_item ->> 'topic'), ''), 'Geral'),
      trim(v_item ->> 'statement'),
      v_item -> 'options'
    ) returning id into v_question_id;
    insert into private.question_keys (question_id, correct_index)
      values (v_question_id, v_correct);
  end loop;

  update public.exams
  set status = 'published', is_public = true, updated_at = now()
  where id = v_exam_id;
  return v_exam_id;
end;
$$;

-- Corrects an attempt without exposing the answer-key table. Anonymous users
-- receive the result; authenticated users also receive a persisted history.
create or replace function public.submit_exam_attempt(
  p_exam_id uuid,
  p_answers jsonb,
  p_review_question_ids uuid[] default '{}',
  p_duration_seconds integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_user uuid := auth.uid();
  v_attempt_id uuid;
  v_total integer;
  v_correct integer;
  v_review jsonb;
begin
  if not exists (
    select 1 from public.exams
    where id = p_exam_id and status = 'published' and is_public
  ) then
    raise exception 'exam unavailable';
  end if;
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    raise exception 'invalid answers';
  end if;

  select count(*), count(*) filter (
    where (p_answers ->> q.id::text) is not null
      and (p_answers ->> q.id::text)::integer = k.correct_index
  )
  into v_total, v_correct
  from public.questions q
  join private.question_keys k on k.question_id = q.id
  where q.exam_id = p_exam_id;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', q.id,
      'position', q.position,
      'selected_index', case when (p_answers ->> q.id::text) is null
        then null else (p_answers ->> q.id::text)::integer end,
      'correct_index', k.correct_index,
      'is_correct', (p_answers ->> q.id::text)::integer = k.correct_index
    ) order by q.position
  ) into v_review
  from public.questions q
  join private.question_keys k on k.question_id = q.id
  where q.exam_id = p_exam_id;

  if v_user is not null then
    insert into public.attempts (
      user_id, exam_id, duration_seconds, correct_count, total_count,
      score_percent, completed_at
    ) values (
      v_user, p_exam_id, greatest(p_duration_seconds, 0), v_correct, v_total,
      round(v_correct::numeric * 100 / greatest(v_total, 1))::integer, now()
    ) returning id into v_attempt_id;

    insert into public.attempt_answers (
      attempt_id, question_id, selected_index, is_correct, marked_for_review
    )
    select
      v_attempt_id,
      q.id,
      case when (p_answers ->> q.id::text) is null
        then null else (p_answers ->> q.id::text)::integer end,
      coalesce((p_answers ->> q.id::text)::integer = k.correct_index, false),
      q.id = any(coalesce(p_review_question_ids, '{}'::uuid[]))
    from public.questions q
    join private.question_keys k on k.question_id = q.id
    where q.exam_id = p_exam_id;

    update public.exams set attempts_count = attempts_count + 1
      where id = p_exam_id;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'total', v_total,
    'correct', v_correct,
    'score_percent', round(v_correct::numeric * 100 / greatest(v_total, 1)),
    'review', coalesce(v_review, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  from public, anon;
grant execute on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  to authenticated;
revoke all on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer)
  from public;
grant execute on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer)
  to anon, authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.profiles, public.exams, public.questions to anon, authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant select on public.attempts, public.attempt_answers to authenticated;
