-- Validate all published content at the trust boundary. The app remains a
-- convenience validator; no client payload is trusted by this function.
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
  v_option jsonb;
  v_question_id uuid;
  v_position integer := 0;
  v_correct integer;
  v_statement text;
  v_topic text;
  v_invalid_option boolean;
  v_unknown_key text;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_title is null or char_length(btrim(p_title)) not between 3 and 180
     or p_category is null or char_length(btrim(p_category)) not between 2 and 80
     or p_source is null or char_length(btrim(p_source)) not between 2 and 160
     or p_source_type is null
     or p_source_type not in ('official', 'community', 'unverified')
     or (p_year is not null and p_year not between 1900 and 2200)
     or p_duration_minutes is null
     or p_duration_minutes not between 1 and 1440 then
    raise exception 'invalid exam metadata' using errcode = '22023';
  end if;

  if jsonb_typeof(p_questions) is distinct from 'array' then
    raise exception 'invalid question list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_questions) not between 1 and 300
     or octet_length(p_questions::text) > 8388608 then
    raise exception 'invalid question list' using errcode = '22023';
  end if;

  insert into public.exams (
    author_id, title, description, category, source_name, source_type,
    year, duration_minutes, status, is_public, question_count
  ) values (
    v_user, btrim(p_title), 'Prova revisada e publicada pela comunidade.',
    btrim(p_category), btrim(p_source), p_source_type, p_year,
    p_duration_minutes, 'draft', false, jsonb_array_length(p_questions)
  ) returning id into v_exam_id;

  for v_item in select value from jsonb_array_elements(p_questions)
  loop
    v_position := v_position + 1;
    if jsonb_typeof(v_item) is distinct from 'object' then
      raise exception 'invalid question at position %', v_position
        using errcode = '22023';
    end if;

    select key into v_unknown_key
    from jsonb_object_keys(v_item) as keys(key)
    where key not in ('statement', 'options', 'correct_index', 'topic')
    limit 1;
    if v_unknown_key is not null then
      raise exception 'unsupported question field at position %', v_position
        using errcode = '22023';
    end if;

    if jsonb_typeof(v_item -> 'statement') is distinct from 'string' then
      raise exception 'invalid statement at position %', v_position
        using errcode = '22023';
    end if;
    v_statement := btrim(v_item ->> 'statement');
    if char_length(v_statement) not between 2 and 20000 then
      raise exception 'invalid statement at position %', v_position
        using errcode = '22023';
    end if;

    if v_item ? 'topic'
       and jsonb_typeof(v_item -> 'topic') is distinct from 'string' then
      raise exception 'invalid topic at position %', v_position
        using errcode = '22023';
    end if;
    v_topic := coalesce(nullif(btrim(v_item ->> 'topic'), ''), 'Geral');
    if char_length(v_topic) not between 1 and 100 then
      raise exception 'invalid topic at position %', v_position
        using errcode = '22023';
    end if;

    if jsonb_typeof(v_item -> 'options') is distinct from 'array' then
      raise exception 'invalid options or answer at position %', v_position
        using errcode = '22023';
    end if;
    if jsonb_array_length(v_item -> 'options') not between 2 and 8
       or coalesce(v_item ->> 'correct_index', '') !~ '^(0|[1-7])$' then
      raise exception 'invalid options or answer at position %', v_position
        using errcode = '22023';
    end if;
    v_correct := (v_item ->> 'correct_index')::integer;
    if v_correct >= jsonb_array_length(v_item -> 'options') then
      raise exception 'answer out of range at position %', v_position
        using errcode = '22023';
    end if;

    v_invalid_option := false;
    for v_option in select value from jsonb_array_elements(v_item -> 'options')
    loop
      if jsonb_typeof(v_option) = 'string' then
        if char_length(btrim(v_option #>> '{}')) not between 1 and 4000 then
          v_invalid_option := true;
        end if;
      elsif jsonb_typeof(v_option) = 'object'
        and jsonb_typeof(v_option -> 'text') = 'string' then
        if char_length(btrim(v_option ->> 'text')) not between 1 and 4000 then
          v_invalid_option := true;
        end if;
      else
        v_invalid_option := true;
      end if;
    end loop;
    if v_invalid_option then
      raise exception 'invalid option text at position %', v_position
        using errcode = '22023';
    end if;

    insert into public.questions (
      exam_id, position, topic, statement, options
    ) values (
      v_exam_id, v_position, v_topic, v_statement, v_item -> 'options'
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

alter function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  owner to postgres;
revoke all on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  from public, anon, authenticated;
grant execute on function public.publish_exam(text, text, text, text, integer, integer, jsonb)
  to authenticated;

notify pgrst, 'reload schema';
