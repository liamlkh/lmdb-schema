-- Allow 'flight' as a location type (in-flight viewings).
-- Safe to run on DBs created before flight type existed.

alter table locations drop constraint if exists locations_type_check;

alter table locations
  add constraint locations_type_check
  check (type in ('cinema', 'residential', 'flight', 'others'));

-- Normalize existing Flight venue rows if they were stored as 'others'.
update locations
set type = 'flight'
where lower(name) = 'flight'
  and type = 'others';
