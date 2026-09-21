-- Idempotent attempt submission for authenticated users and visitors.
-- IDs are globally unique. Visitor attempts use user_id NULL and remain hidden
-- by the existing RLS. Their unguessable UUID acts only as a retry key for a
-- public exam; it grants no table access and returns no data beyond this RPC.

alter table public.attempts
  add column if not exists client_attempt_id uuid,
  add column if not exists request_payload jsonb;

-- NULL client IDs preserve historical rows without a backfill.
create unique index if not exists attempts_client_attempt_uidx
  on public.attempts (client_attempt_id)
  where client_attempt_id is not null;

create or replace function public.submit_exam_attempt(
  p_exam_id uuid,
  p_answers jsonb,
  p_review_question_ids uuid[],
  p_duration_seconds integer,
  p_client_attempt_id uuid
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
  v_inserted boolean := false;
  v_existing_user uuid;
  v_existing_exam_id uuid;
  v_existing_payload jsonb;
  v_request_payload jsonb;
begin
  if p_client_attempt_id is null then
    raise exception 'client attempt id required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.exams
    where id = p_exam_id and status = 'published' and is_public
  ) then
    raise exception 'exam unavailable' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    raise exception 'invalid answers' using errcode = '22023';
  end if;

  -- JSONB has canonical object-key ordering. Review IDs are de-duplicated and
  -- sorted so semantically equivalent requests compare equal.
  select jsonb_build_object(
    'exam_id', p_exam_id,
    'answers', coalesce(p_answers, '{}'::jsonb),
    'review_question_ids', coalesce(
      (
        select jsonb_agg(ids.question_id order by ids.question_id)
        from (
          select distinct unnest(
            coalesce(p_review_question_ids, '{}'::uuid[])
          ) as question_id
        ) ids
      ),
      '[]'::jsonb
    ),
    'duration_seconds', greatest(coalesce(p_duration_seconds, 0), 0)
  ) into v_request_payload;

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
      'is_correct', (p_answers ->> q.id::text)::integer = k.correct_index,
      'marked_for_review', q.id = any(
        coalesce(p_review_question_ids, '{}'::uuid[])
      )
    ) order by q.position
  ) into v_review
  from public.questions q
  join private.question_keys k on k.question_id = q.id
  where q.exam_id = p_exam_id;

  insert into public.attempts (
    user_id, exam_id, client_attempt_id, request_payload,
    duration_seconds, correct_count, total_count, score_percent, completed_at
  ) values (
    v_user, p_exam_id, p_client_attempt_id, v_request_payload,
    greatest(coalesce(p_duration_seconds, 0), 0), v_correct, v_total,
    round(v_correct::numeric * 100 / greatest(v_total, 1))::integer, now()
  )
  on conflict (client_attempt_id)
    where client_attempt_id is not null do nothing
  returning id into v_attempt_id;

  if v_attempt_id is not null then
    v_inserted := true;
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
  else
    select id, user_id, exam_id, request_payload, total_count, correct_count
    into v_attempt_id, v_existing_user, v_existing_exam_id,
      v_existing_payload, v_total, v_correct
    from public.attempts
    where client_attempt_id = p_client_attempt_id;

    if v_attempt_id is null then
      raise exception 'idempotent attempt not found' using errcode = '40001';
    end if;
    if v_existing_user is not null and v_existing_user is distinct from v_user then
      raise exception 'client attempt belongs to another user'
        using errcode = '42501';
    end if;
    if v_existing_exam_id <> p_exam_id
       or v_existing_payload <> v_request_payload then
      raise exception 'client attempt id reused with different payload'
        using errcode = '22023';
    end if;

    -- An authenticated retry may claim an equivalent visitor attempt. The
    -- conditional UPDATE makes competing claims atomic. A loser re-reads the
    -- owner and receives 42501 instead of returning another user's attempt.
    if v_existing_user is null and v_user is not null then
      update public.attempts
      set user_id = v_user
      where id = v_attempt_id
        and user_id is null
        and request_payload = v_request_payload
      returning user_id into v_existing_user;

      if v_existing_user is null then
        select user_id into v_existing_user
        from public.attempts
        where id = v_attempt_id;
      end if;

      if v_existing_user is distinct from v_user then
        raise exception 'client attempt belongs to another user'
          using errcode = '42501';
      end if;
    end if;

    select jsonb_agg(
      jsonb_build_object(
        'question_id', q.id,
        'position', q.position,
        'selected_index', aa.selected_index,
        'correct_index', k.correct_index,
        'is_correct', aa.is_correct,
        'marked_for_review', aa.marked_for_review
      ) order by q.position
    ) into v_review
    from public.attempt_answers aa
    join public.questions q on q.id = aa.question_id
    join private.question_keys k on k.question_id = q.id
    where aa.attempt_id = v_attempt_id;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'duplicate', not v_inserted,
    'total', v_total,
    'correct', v_correct,
    'score_percent', round(v_correct::numeric * 100 / greatest(v_total, 1)),
    'review', coalesce(v_review, '[]'::jsonb)
  );
end;
$$;

-- SECURITY DEFINER runs with postgres privileges; callers receive EXECUTE only.
alter function public.submit_exam_attempt(uuid, jsonb, uuid[], integer, uuid)
  owner to postgres;
revoke all on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer, uuid)
  from public, anon, authenticated;
grant execute on function public.submit_exam_attempt(uuid, jsonb, uuid[], integer, uuid)
  to anon, authenticated;

-- The old four-argument overload remains for old clients. A named five-argument
-- call resolves only to this overload, avoiding PostgREST ambiguity.
--
-- Rollback before clients depend on this signature (attempt rows are preserved):
-- drop function public.submit_exam_attempt(uuid, jsonb, uuid[], integer, uuid);
-- drop index public.attempts_client_attempt_uidx;
-- alter table public.attempts drop column request_payload;
-- alter table public.attempts drop column client_attempt_id;
