-- Defense in depth for answer keys. No direct policies are intentional:
-- only the narrowly granted SECURITY DEFINER RPCs may access this table.
alter table private.question_keys enable row level security;
