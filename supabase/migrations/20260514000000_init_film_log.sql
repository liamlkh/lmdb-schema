-- Film Log: initial schema
-- Run with: supabase db push
-- Or paste into the SQL editor at https://app.supabase.com

-- =====================================================================
-- Tables
-- =====================================================================

-- Venues where films are watched. Scoped per user.
create table if not exists locations (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  type            text not null default 'cinema'
                    check (type in ('cinema', 'residential', 'others')),
  google_place_id text,
  created_at      timestamptz not null default now()
);

-- Index for autocomplete-style lookups by name
create index if not exists locations_name_idx on locations (lower(name));
create index if not exists locations_type_idx on locations (type);

-- The log itself. One row per film viewing.
create table if not exists logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,

  -- Film metadata cached from TMDB so the log reads offline
  tmdb_id       int not null,
  title         text not null,
  poster_path   text,
  release_year  int,

  -- Viewing details
  watched_at    timestamptz not null,
  location_id   uuid references locations(id) on delete set null,
  house         text,                    -- free text: 'House 4', 'IMAX', etc.

  my_seat       text,                    -- 'F12'
  -- Companions are tracked in the `companions` + `log_companions` tables
  -- (see below). Per-log seat for each companion lives in the junction row.

  note          text,
  rating        numeric(2,1) check (rating is null or rating between 0 and 5),

  created_at    timestamptz not null default now()
);

create index if not exists logs_user_watched_idx
  on logs (user_id, watched_at desc);

create index if not exists logs_tmdb_idx
  on logs (tmdb_id);

create index if not exists logs_location_idx
  on logs (location_id);

-- People you watch films with. Scoped per user.
-- Retrievable as a standalone list (e.g. for autocomplete).
create table if not exists companions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  notes       text,
  created_at  timestamptz not null default now(),
  unique (user_id, name)
);

create index if not exists companions_user_idx on companions (user_id, lower(name));

-- Junction: which companions came to a given log, with optional per-log seat.
-- seat is nullable -> a companion can be linked without knowing their seat.
create table if not exists log_companions (
  log_id        uuid not null references logs(id) on delete cascade,
  companion_id  uuid not null references companions(id) on delete cascade,
  seat          text,                    -- 'F13', or null if unknown
  primary key (log_id, companion_id)
);

create index if not exists log_companions_companion_idx
  on log_companions (companion_id);

-- =====================================================================
-- Row Level Security
-- =====================================================================

alter table locations        enable row level security;
alter table logs             enable row level security;
alter table companions       enable row level security;
alter table log_companions   enable row level security;

-- Locations: anyone (even anon) can read; authenticated users can add/edit.
drop policy if exists "Locations are readable by anyone"   on locations;
drop policy if exists "Authed users can insert locations"  on locations;
drop policy if exists "Authed users can update locations"  on locations;

create policy "Locations are readable by anyone"
  on locations for select
  using (true);

create policy "Authed users can insert locations"
  on locations for insert
  to authenticated
  with check (true);

create policy "Authed users can update locations"
  on locations for update
  to authenticated
  using (true) with check (true);

-- Logs: scoped strictly to the owning user.
drop policy if exists "Users read own logs"    on logs;
drop policy if exists "Users insert own logs"  on logs;
drop policy if exists "Users update own logs"  on logs;
drop policy if exists "Users delete own logs"  on logs;

create policy "Users read own logs"
  on logs for select
  using (auth.uid() = user_id);

create policy "Users insert own logs"
  on logs for insert
  with check (auth.uid() = user_id);

create policy "Users update own logs"
  on logs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete own logs"
  on logs for delete
  using (auth.uid() = user_id);

-- Companions: scoped strictly to the owning user.
drop policy if exists "Users read own companions"    on companions;
drop policy if exists "Users insert own companions"  on companions;
drop policy if exists "Users update own companions"  on companions;
drop policy if exists "Users delete own companions"  on companions;

create policy "Users read own companions"
  on companions for select
  using (auth.uid() = user_id);

create policy "Users insert own companions"
  on companions for insert
  with check (auth.uid() = user_id);

create policy "Users update own companions"
  on companions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete own companions"
  on companions for delete
  using (auth.uid() = user_id);

-- Log <-> companion links: scoped by the owning log.
drop policy if exists "Users read own log companions"   on log_companions;
drop policy if exists "Users write own log companions"  on log_companions;

create policy "Users read own log companions"
  on log_companions for select
  using (
    exists (
      select 1 from logs
      where logs.id = log_companions.log_id
        and logs.user_id = auth.uid()
    )
  );

create policy "Users write own log companions"
  on log_companions for all
  using (
    exists (
      select 1 from logs
      where logs.id = log_companions.log_id
        and logs.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from logs
      where logs.id = log_companions.log_id
        and logs.user_id = auth.uid()
    )
  );
