-- TEST ONLY. Reproduce deployed schema drift in a disposable local database.
-- Run after core schema and before secure_attempt_delivery. Never in production.
alter table public.attempts alter column user_id set not null;
grant all on public.attempts, public.attempt_answers to anon, authenticated;
create policy attempts_owner_insert on public.attempts
  for insert to authenticated with check (auth.uid() = user_id);
create policy attempts_owner_delete on public.attempts
  for delete to authenticated using (auth.uid() = user_id);
create policy attempt_answers_owner_insert on public.attempt_answers
  for insert to authenticated with check (exists (
    select 1 from public.attempts a
    where a.id = attempt_id and a.user_id = auth.uid()
  ));
create policy attempt_answers_owner_delete on public.attempt_answers
  for delete to authenticated using (exists (
    select 1 from public.attempts a
    where a.id = attempt_id and a.user_id = auth.uid()
  ));
