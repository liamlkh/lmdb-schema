-- Auto-assign user_id on insert so clients don't need to pass it explicitly.

create or replace function public.locations_set_user_id()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.user_id := auth.uid();
  return new;
end;
$$;

drop trigger if exists locations_set_user_id on public.locations;

create trigger locations_set_user_id
  before insert on public.locations
  for each row
  execute function public.locations_set_user_id();
