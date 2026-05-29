-- Allow logging a viewing by date only; time is optional.

alter table logs
  add column watched_date date,
  add column watched_time time;

update logs
set
  watched_date = watched_at::date,
  watched_time = nullif(watched_at::time, time '00:00:00');

alter table logs
  alter column watched_date set not null;

drop index if exists logs_user_watched_idx;

alter table logs
  drop column watched_at;

create index logs_user_watched_idx
  on logs (user_id, watched_date desc, watched_time desc nulls last);
