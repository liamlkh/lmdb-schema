-- Optional image URL for a venue.

alter table locations
  add column if not exists image_url text;
