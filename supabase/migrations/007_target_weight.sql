-- Target weight + target date: "lose 5 kg within 8 weeks" -> daily calories.
-- The app sends the number of weeks; the server stores the date it ends.
-- Run once in Supabase SQL Editor. Safe to run again.

alter table public.user_profiles add column if not exists target_weight numeric(5, 2)
  check (target_weight > 0 and target_weight < 400);  -- kg
alter table public.user_profiles add column if not exists target_date date;
