-- Remember the weight and the day the target was set,
-- so the app can show "lost 8 of 30 kg (27%)".
-- Run once in Supabase SQL Editor. Safe to run again.

alter table public.user_profiles add column if not exists target_start_weight numeric(5, 2)
  check (target_start_weight > 0 and target_start_weight < 400);  -- kg
alter table public.user_profiles add column if not exists target_set_at date;

-- targets set before this migration: start from the current weight, today
update public.user_profiles
set target_start_weight = weight, target_set_at = current_date
where target_weight is not null and target_start_weight is null;

notify pgrst, 'reload schema';
