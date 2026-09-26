-- Integration tests for 202609210003_attempt_idempotency.sql.
-- This file expects a disposable database with the minimal local auth mock from
-- scripts/local_db_test.sh. It must never be executed against production.

\set ON_ERROR_STOP on

insert into auth.users (id, raw_user_meta_data) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '{"display_name":"Usuário A"}'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '{"display_name":"Usuário B"}');

insert into public.exams (
  id, author_id, title, description, category, source_name, source_type,
  duration_minutes, status, is_public, question_count
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Prova local', '', 'Teste', 'Fixture local', 'official',
  30, 'published', true, 1
);

insert into public.questions (
  id, exam_id, position, topic, statement, options
) values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  1, 'Teste', 'Questão local?', '["A", "B"]'
);
insert into private.question_keys (question_id, correct_index) values
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1);

-- First authenticated delivery and equivalent repetition.
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  false
);
do $$
declare
  first_result jsonb;
  repeated_result jsonb;
begin
  first_result := public.submit_exam_attempt(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
    '{}'::uuid[], 30, '11111111-1111-4111-8111-111111111111'
  );
  repeated_result := public.submit_exam_attempt(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
    '{}'::uuid[], 30, '11111111-1111-4111-8111-111111111111'
  );
  if (first_result ->> 'duplicate')::boolean then
    raise exception 'first authenticated delivery marked duplicate';
  end if;
  if not (repeated_result ->> 'duplicate')::boolean then
    raise exception 'authenticated retry not marked duplicate';
  end if;
  if first_result ->> 'attempt_id' <> repeated_result ->> 'attempt_id' then
    raise exception 'authenticated retry returned another attempt';
  end if;
end
$$;

-- RLS shows the owner only their attempt and answers.
do $$
begin
  if (select count(*) from public.attempts) <> 1 then
    raise exception 'owner cannot read exactly one attempt';
  end if;
  if (select count(*) from public.attempt_answers) <> 1 then
    raise exception 'owner cannot read exactly one answer';
  end if;
end
$$;

-- A different payload with the same ID is rejected permanently.
do $$
declare
  state text;
begin
  begin
    perform public.submit_exam_attempt(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 0),
      '{}'::uuid[], 30, '11111111-1111-4111-8111-111111111111'
    );
    raise exception 'different payload was accepted';
  exception when others then
    get stacked diagnostics state = returned_sqlstate;
    if state <> '22023' then
      raise exception 'different payload returned %, expected 22023', state;
    end if;
  end;
end
$$;

-- Another user cannot access or reclaim an owned attempt.
select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  false
);
do $$
declare
  state text;
begin
  if (select count(*) from public.attempts) <> 0 then
    raise exception 'RLS exposed another user attempt';
  end if;
  if (select count(*) from public.attempt_answers) <> 0 then
    raise exception 'RLS exposed another user answers';
  end if;
  begin
    perform public.submit_exam_attempt(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
      '{}'::uuid[], 30, '11111111-1111-4111-8111-111111111111'
    );
    raise exception 'another user reclaimed an owned attempt';
  exception when others then
    get stacked diagnostics state = returned_sqlstate;
    if state <> '42501' then
      raise exception 'other owner returned %, expected 42501', state;
    end if;
  end;
end
$$;

-- Visitor retry creates one anonymous row and returns the original result.
reset role;
select set_config('request.jwt.claim.sub', '', false);
set role anon;
do $$
declare
  first_result jsonb;
  repeated_result jsonb;
begin
  first_result := public.submit_exam_attempt(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
    array['dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid],
    35, '22222222-2222-4222-8222-222222222222'
  );
  repeated_result := public.submit_exam_attempt(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
    array['dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid],
    35, '22222222-2222-4222-8222-222222222222'
  );
  if first_result ->> 'attempt_id' <> repeated_result ->> 'attempt_id' then
    raise exception 'visitor retry returned another attempt';
  end if;
  if not (repeated_result ->> 'duplicate')::boolean then
    raise exception 'visitor retry not marked duplicate';
  end if;
end
$$;

-- Equivalent authenticated retry atomically claims the visitor row.
reset role;
set role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  false
);
do $$
declare
  claimed jsonb;
begin
  claimed := public.submit_exam_attempt(
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1),
    array['dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid],
    35, '22222222-2222-4222-8222-222222222222'
  );
  if not (claimed ->> 'duplicate')::boolean then
    raise exception 'visitor claim was not an idempotent retry';
  end if;
  if (select count(*) from public.attempts
      where client_attempt_id = '22222222-2222-4222-8222-222222222222'
        and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') <> 1 then
    raise exception 'visitor attempt was not linked to authenticated user';
  end if;
end
$$;

reset role;

-- PUBLIC has no EXECUTE; only anon and authenticated do.
do $$
begin
  if exists (
    select 1 from information_schema.role_routine_grants
    where routine_schema = 'public'
      and routine_name = 'submit_exam_attempt'
      and specific_name like 'submit_exam_attempt_%'
      and grantee = 'PUBLIC'
  ) then
    raise exception 'PUBLIC can execute submit_exam_attempt';
  end if;
  if not has_function_privilege(
    'anon',
    'public.submit_exam_attempt(uuid,jsonb,uuid[],integer,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.submit_exam_attempt(uuid,jsonb,uuid[],integer,uuid)',
    'EXECUTE'
  ) then
    raise exception 'expected role grant is missing';
  end if;
end
$$;

-- Rollback recipe preserves existing attempt rows. DDL is transactional, so
-- this exercises the documented operations and then restores the schema.
begin;
drop function public.submit_exam_attempt(uuid, jsonb, uuid[], integer, uuid);
drop index public.attempts_client_attempt_uidx;
alter table public.attempts drop column request_payload;
alter table public.attempts drop column client_attempt_id;
do $$
begin
  if (select count(*) from public.attempts) <> 2 then
    raise exception 'rollback operations removed attempt rows';
  end if;
end
$$;
rollback;

select 'attempt idempotency tests passed' as result;
