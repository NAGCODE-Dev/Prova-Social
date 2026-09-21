-- Manual integration test for 202609210003_attempt_idempotency.sql.
-- Run only against an isolated database after the core migrations.
-- Required psql variables:
--   user_a, user_b: existing auth.users/profile UUIDs
--   exam_id: a published public exam UUID
--   question_id: a question from exam_id with a private.question_keys row
-- Example payload below selects option zero. Adjust it to the fixture if needed.
-- Every block rolls back or performs read-only assertions. Never run this file
-- against production data.

\set client_id '11111111-1111-4111-8111-111111111111'
\set visitor_id '22222222-2222-4222-8222-222222222222'

-- 1. First authenticated delivery. Expected: duplicate=false and one attempt.
begin;
set local role authenticated;
create temporary table attempt_test_results (result jsonb) on commit drop;
select set_config('request.jwt.claim.sub', :'user_a', true);
insert into attempt_test_results
select public.submit_exam_attempt(
  :'exam_id', jsonb_build_object(:'question_id', 0), '{}'::uuid[], 30,
  :'client_id'
);
reset role;
do $$
begin
  if (select (result ->> 'duplicate')::boolean from attempt_test_results) then
    raise exception 'first delivery was reported as duplicate';
  end if;
end;
$$;
rollback;

-- 2. Repeated authenticated delivery. Run without the rollback from block 1 in
-- a disposable database, then call twice. Expected: same attempt_id, with the
-- second response reporting duplicate=true and attempts_count incremented once.

-- 3. Concurrent delivery. In two psql sessions, begin both transactions, set
-- role/JWT to user_a and execute this same call with one new client ID:
-- select public.submit_exam_attempt(
--   :'exam_id', jsonb_build_object(:'question_id', 0), '{}'::uuid[], 30,
--   '33333333-3333-4333-8333-333333333333'
-- );
-- Commit session A, then session B. Expected: one attempts row, one set of
-- attempt_answers, identical attempt_id responses, and one duplicate=true.

-- 4. Visitor retry. Clear JWT claims and call twice with visitor_id. Expected:
-- one attempts row with user_id NULL and the same attempt_id on both calls.
-- select set_config('request.jwt.claims', '{}', false);
-- set role anon;
-- select public.submit_exam_attempt(
--   :'exam_id', jsonb_build_object(:'question_id', 0), '{}'::uuid[], 30,
--   :'visitor_id'
-- );

-- 4a. Visitor -> authenticated claim. After block 4 has committed, repeat the
-- exact visitor request with user_a's JWT. Expected: same attempt_id, duplicate
-- true, and the existing row changes from user_id NULL to user_a. It must then
-- appear under the existing attempts_owner_read RLS policy:
-- set role authenticated;
-- select set_config('request.jwt.claim.sub', :'user_a', false);
-- select public.submit_exam_attempt(
--   :'exam_id', jsonb_build_object(:'question_id', 0), '{}'::uuid[], 30,
--   :'visitor_id'
-- );
-- select count(*) from public.attempts
-- where client_attempt_id = :'visitor_id'
--   and user_id = :'user_a'; -- expected 1

-- 4b. Claim preconditions and race. A different client ID inserts another row;
-- it never claims visitor_id. Reusing visitor_id with a changed answer must fail
-- with 22023 while its user_id remains NULL. To test competing equivalent claims,
-- submit visitor_id concurrently as user_a and user_b in two sessions. Exactly
-- one UPDATE ... WHERE user_id IS NULL wins; the winner sees the original result
-- and owns the row, while the loser receives 42501.

-- 5. Same ID with a different payload. After a successful call, changing the
-- selected option, exam, review set, or duration must fail with SQLSTATE 22023:
-- select public.submit_exam_attempt(
--   :'exam_id', jsonb_build_object(:'question_id', 1), '{}'::uuid[], 30,
--   :'client_id'
-- );

-- 6. Another user cannot claim or inspect user_a's attempt. Expected RPC error
-- SQLSTATE 42501 and zero rows from the RLS-protected direct query:
-- set role authenticated;
-- select set_config('request.jwt.claim.sub', :'user_b', false);
-- select public.submit_exam_attempt(
--   :'exam_id', jsonb_build_object(:'question_id', 0), '{}'::uuid[], 30,
--   :'client_id'
-- );
-- select count(*) from public.attempts
-- where client_attempt_id = :'client_id'; -- expected 0

-- 7. A role without an explicit grant cannot execute the function. As a
-- database administrator, use a temporary NOLOGIN role and expect 42501:
-- create role attempt_test_unprivileged nologin;
-- set role attempt_test_unprivileged;
-- select public.submit_exam_attempt(
--   :'exam_id', '{}'::jsonb, '{}'::uuid[], 0,
--   '44444444-4444-4444-8444-444444444444'
-- );
-- reset role;
-- drop role attempt_test_unprivileged;

-- Permission audit. PUBLIC must be absent; anon/authenticated must have EXECUTE.
select
  not exists (
    select 1
    from information_schema.role_routine_grants
    where routine_schema = 'public'
      and routine_name = 'submit_exam_attempt'
      and grantee = 'PUBLIC'
  ) as public_execute_absent_must_be_true,
  has_function_privilege(
    'anon',
    'public.submit_exam_attempt(uuid,jsonb,uuid[],integer,uuid)',
    'EXECUTE'
  ) as anon_must_be_true,
  has_function_privilege(
    'authenticated',
    'public.submit_exam_attempt(uuid,jsonb,uuid[],integer,uuid)',
    'EXECUTE'
  ) as authenticated_must_be_true;
