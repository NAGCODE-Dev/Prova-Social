-- Transactional smoke test for an authorized deployed project.
-- Uses one existing profile without changing it. All fixture rows are rolled
-- back. No auth user is created and no persistent test content is published.
begin;
set local statement_timeout = '20s';
set local lock_timeout = '5s';
do $$
declare
  owner_id uuid;
  exam_id uuid := gen_random_uuid();
  question_id uuid := gen_random_uuid();
begin
  select id into owner_id from public.profiles limit 1;
  if owner_id is null then
    raise exception 'Smoke test requires an existing profile';
  end if;
  perform set_config('prova_test.owner', owner_id::text, true);
  perform set_config('prova_test.exam', exam_id::text, true);
  perform set_config('prova_test.question', question_id::text, true);
  perform set_config('prova_test.client', gen_random_uuid()::text, true);
  insert into public.exams (
    id, author_id, title, category, source_name, source_type,
    duration_minutes, status, is_public, question_count
  ) values (
    exam_id, owner_id, 'Transactional smoke test', 'Teste', 'Teste transacional',
    'unverified', 10, 'published', true, 1
  );
  insert into public.questions (id, exam_id, position, topic, statement, options)
    values (question_id, exam_id, 1, 'Teste', 'Questão transacional?', '["A", "B"]');
  insert into private.question_keys (question_id, correct_index) values (question_id, 1);
end
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);
do $$
declare
  first_result jsonb;
  repeated jsonb;
begin
  first_result := public.submit_exam_attempt(
    current_setting('prova_test.exam')::uuid,
    jsonb_build_object(current_setting('prova_test.question'), 1),
    '{}'::uuid[], 10, current_setting('prova_test.client')::uuid
  );
  repeated := public.submit_exam_attempt(
    current_setting('prova_test.exam')::uuid,
    jsonb_build_object(current_setting('prova_test.question'), 1),
    '{}'::uuid[], 10, current_setting('prova_test.client')::uuid
  );
  if (first_result ->> 'duplicate')::boolean or
     not (repeated ->> 'duplicate')::boolean or
     first_result ->> 'attempt_id' is distinct from repeated ->> 'attempt_id' or
     (first_result ->> 'correct')::integer <> 1 then
    raise exception 'visitor retry regression';
  end if;
  begin
    perform public.submit_exam_attempt(
      current_setting('prova_test.exam')::uuid,
      jsonb_build_object(current_setting('prova_test.question'), 0),
      '{}'::uuid[], 10, current_setting('prova_test.client')::uuid
    );
    raise exception 'conflicting payload accepted';
  exception when sqlstate '22023' then null;
  end;
end
$$;

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', current_setting('prova_test.owner'), true);
do $$
declare
  claimed jsonb;
  legacy jsonb;
begin
  claimed := public.submit_exam_attempt(
    current_setting('prova_test.exam')::uuid,
    jsonb_build_object(current_setting('prova_test.question'), 1),
    '{}'::uuid[], 10, current_setting('prova_test.client')::uuid
  );
  if not (claimed ->> 'duplicate')::boolean or
     (select count(*) from public.attempts
      where client_attempt_id = current_setting('prova_test.client')::uuid
        and user_id = auth.uid()) <> 1 then
    raise exception 'visitor claim regression';
  end if;
  legacy := public.submit_exam_attempt(
    current_setting('prova_test.exam')::uuid,
    jsonb_build_object(current_setting('prova_test.question'), 1),
    '{}'::uuid[], 10
  );
  if legacy ->> 'attempt_id' is null or (legacy ->> 'correct')::integer <> 1 then
    raise exception 'legacy RPC regression';
  end if;
  if (select count(*) from public.attempts
      where exam_id = current_setting('prova_test.exam')::uuid) <> 2 then
    raise exception 'unexpected duplicate rows';
  end if;
  begin
    delete from public.attempts where exam_id = current_setting('prova_test.exam')::uuid;
    raise exception 'direct delete was permitted';
  exception when insufficient_privilege then null;
  end;
end
$$;

-- Another identity sees neither attempts nor their answers and cannot claim.
select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
do $$
begin
  if exists (select 1 from public.attempts
             where exam_id = current_setting('prova_test.exam')::uuid) or
     exists (select 1 from public.attempt_answers
             where question_id = current_setting('prova_test.question')::uuid) then
    raise exception 'RLS exposed another identity';
  end if;
  begin
    perform public.submit_exam_attempt(
      current_setting('prova_test.exam')::uuid,
      jsonb_build_object(current_setting('prova_test.question'), 1),
      '{}'::uuid[], 10, current_setting('prova_test.client')::uuid
    );
    raise exception 'another identity claimed the attempt';
  exception when insufficient_privilege then null;
  end;
end
$$;
rollback;
select 'PASS: visitor, retry, claim, legacy RPC, RLS; fixtures rolled back' as result;
