-- Scope locations to the owning user (per-user venues, like companions).

alter table locations
  add column user_id uuid references auth.users(id) on delete cascade;

-- Assign each location to the user from its earliest log.
update locations l
set user_id = (
  select l2.user_id
  from logs l2
  where l2.location_id = l.id
  order by l2.watched_at asc
  limit 1
)
where user_id is null
  and exists (select 1 from logs l2 where l2.location_id = l.id);

-- Other users sharing a venue get their own copy.
do $$
declare
  r record;
  new_location_id uuid;
begin
  for r in
    select distinct l.id as location_id, logs.user_id
    from logs
    join locations l on l.id = logs.location_id
    where l.user_id is distinct from logs.user_id
  loop
    insert into locations (name, type, google_place_id, created_at, user_id)
    select name, type, google_place_id, created_at, r.user_id
    from locations
    where id = r.location_id
    returning id into new_location_id;

    update logs
    set location_id = new_location_id
    where location_id = r.location_id
      and user_id = r.user_id;
  end loop;
end $$;

-- Drop venues never referenced by any log.
delete from locations where user_id is null;

alter table locations alter column user_id set not null;

-- Collapse duplicate names per user before adding uniqueness.
do $$
declare
  r record;
  keep_id uuid;
  i int;
begin
  for r in
    select user_id, name, array_agg(id order by created_at) as ids
    from locations
    group by user_id, name
    having count(*) > 1
  loop
    keep_id := r.ids[1];
    for i in 2..array_length(r.ids, 1) loop
      update logs set location_id = keep_id where location_id = r.ids[i];
      delete from locations where id = r.ids[i];
    end loop;
  end loop;
end $$;

drop index if exists locations_name_idx;
create index if not exists locations_user_name_idx on locations (user_id, lower(name));

alter table locations
  add constraint locations_user_name_key unique (user_id, name);

-- RLS: owner-only
drop policy if exists "Locations are readable by anyone"   on locations;
drop policy if exists "Authed users can insert locations"  on locations;
drop policy if exists "Authed users can update locations"  on locations;
drop policy if exists "Users read own locations"           on locations;
drop policy if exists "Users insert own locations"         on locations;
drop policy if exists "Users update own locations"         on locations;
drop policy if exists "Users delete own locations"         on locations;

create policy "Users read own locations"
  on locations for select
  using (auth.uid() = user_id);

create policy "Users insert own locations"
  on locations for insert
  with check (auth.uid() = user_id);

create policy "Users update own locations"
  on locations for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete own locations"
  on locations for delete
  using (auth.uid() = user_id);
