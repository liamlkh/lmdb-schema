-- Ensure 'flight' is allowed on locations.type.
-- Needed when 20260527000000 was marked applied via migration repair without running SQL.

do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'locations'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%type%'
  loop
    execute format('alter table locations drop constraint if exists %I', r.conname);
  end loop;
end $$;

alter table locations
  add constraint locations_type_check
  check (type in ('cinema', 'residential', 'flight', 'others'));
