-- Keep the existing publication RPC compatible with already installed apps.
-- This wrapper adds optional source URL persistence without changing its
-- seven-argument signature.
create or replace function public.publish_exam_with_source_url(
  p_title text,
  p_category text,
  p_source text,
  p_source_type text,
  p_year integer,
  p_duration_minutes integer,
  p_questions jsonb,
  p_source_url text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_exam_id uuid;
  v_source_url text := btrim(p_source_url);
begin
  if v_source_url is null
     or char_length(v_source_url) not between 10 and 500
     or v_source_url !~ '^https://[^[:space:]/?#]+([/?#][^[:space:]]*)?$'
     or split_part(split_part(v_source_url, '://', 2), '/', 1) like '%@%' then
    raise exception 'invalid source URL' using errcode = '22023';
  end if;

  v_exam_id := public.publish_exam(
    p_title,
    p_category,
    p_source,
    p_source_type,
    p_year,
    p_duration_minutes,
    p_questions
  );

  update public.exams
  set source_url = v_source_url
  where id = v_exam_id
    and author_id = auth.uid()
    and is_public;

  if not found then
    raise exception 'published exam unavailable' using errcode = '22023';
  end if;

  return v_exam_id;
end;
$$;

alter function public.publish_exam_with_source_url(
  text, text, text, text, integer, integer, jsonb, text
) owner to postgres;
revoke all on function public.publish_exam_with_source_url(
  text, text, text, text, integer, integer, jsonb, text
) from public, anon, authenticated;
grant execute on function public.publish_exam_with_source_url(
  text, text, text, text, integer, integer, jsonb, text
) to authenticated;

notify pgrst, 'reload schema';
