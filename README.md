# lmdb-schema

Supabase database schema for the **LMDB** project. Contains SQL migrations only — no application code.

## Migrations

```
supabase/migrations/
├── 20260514000000_init_film_log.sql      # tables, indexes, RLS
├── 20260527000000_add_flight_location_type.sql  # flight location type
├── 20260527000001_scope_locations_to_user.sql   # per-user venues + RLS
├── 20260527000002_ensure_flight_location_type.sql  # fix type check if repair skipped SQL
├── 20260527000003_locations_set_user_id_trigger.sql  # set user_id from auth on insert
└── 20260527000004_add_location_notes.sql           # optional venue notes
```

## Setup

1. Link to your Supabase project:

   ```bash
   supabase link
   ```

2. Push migrations:

   ```bash
   supabase db push
   ```

   Or paste the migration into the SQL editor at [app.supabase.com](https://app.supabase.com).

## Schema overview

| Table            | Description                                      |
|------------------|--------------------------------------------------|
| `logs`           | One row per film viewing                         |
| `companions`     | People you watch films with, scoped per user     |
| `log_companions` | Junction: which companions attended a given log  |
| `locations`      | Venues scoped per user (`cinema`, `residential`, `flight`, `others`); optional `notes` |

## RLS summary

- `locations`, `logs`, `companions`, `log_companions` — owner-only (scoped to `auth.uid()`)
