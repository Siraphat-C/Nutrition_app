-- Week 5-6 early: save meals in saved_menu (with weight and calories) and keep weight history.
-- Run once in Supabase SQL Editor. Safe to run again.

-- 1) saved_menu: which meal of the day (breakfast / lunch / dinner / snack)
alter table public.saved_menu
  add column if not exists meal_type varchar(20) not null default 'snack';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'saved_menu_meal_type_check'
  ) then
    alter table public.saved_menu
      add constraint saved_menu_meal_type_check
      check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack'));
  end if;
end $$;

-- 2) weight_logs: one row each time the user records their weight
create table if not exists public.weight_logs (
  weight_log_id integer generated always as identity primary key,
  user_id       integer not null references public.users (user_id) on delete cascade,
  weight        numeric(5, 2) not null check (weight > 0 and weight < 400),  -- kg
  logged_at     timestamptz not null default now()
);

create index if not exists weight_logs_user_logged_at_idx
  on public.weight_logs (user_id, logged_at desc);

alter table public.weight_logs enable row level security;

-- 3) start the weight history from the weight already in each profile
insert into public.weight_logs (user_id, weight, logged_at)
select p.user_id, p.weight, coalesce(p.calculated_at, p.updated_at)
from public.user_profiles p
where p.weight is not null
  and not exists (select 1 from public.weight_logs w where w.user_id = p.user_id);
