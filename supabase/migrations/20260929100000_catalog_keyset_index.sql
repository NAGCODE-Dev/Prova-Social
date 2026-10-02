-- Supports stable descending keyset pagination for the public catalog.
create index if not exists exams_public_catalog_cursor_idx
  on public.exams (created_at desc, id desc)
  where status = 'published' and is_public = true;
