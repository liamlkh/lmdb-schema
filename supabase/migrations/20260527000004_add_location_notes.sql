-- Optional notes on a venue (same field name as companions.notes).

alter table locations
  add column if not exists notes text;
