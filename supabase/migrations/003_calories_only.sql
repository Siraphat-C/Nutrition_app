-- Scope change: track calories only (no protein / carbohydrate / fat).
-- Run once in Supabase SQL Editor on a database created from an earlier
-- schema.sql. Values in these columns are deleted.
alter table public.user_profiles
  drop column if exists daily_protein,
  drop column if exists daily_carbohydrate,
  drop column if exists daily_fat;

alter table public.foods
  drop column if exists protein_per_100g,
  drop column if exists carbohydrate_per_100g,
  drop column if exists fat_per_100g;

alter table public.saved_menu
  drop column if exists total_protein,
  drop column if exists total_carbohydrate,
  drop column if exists total_fat;
