-- Week 2 (advisor feedback): exercise logging.
-- Calories burned = MET x body weight (kg) x hours (MET values: 2024 Adult Compendium of Physical Activities).
-- Run once in Supabase SQL Editor. Safe to run again.

create table if not exists public.exercise_logs (
  exercise_log_id  integer generated always as identity primary key,
  user_id          integer not null references public.users (user_id) on delete cascade,
  activity         varchar(50) not null,                                              -- key in exercise.py
  met              numeric(4, 1) not null check (met > 0 and met <= 25),
  duration_minutes integer not null check (duration_minutes between 1 and 600),
  weight_kg        numeric(5, 2) not null check (weight_kg > 0 and weight_kg < 400),  -- body weight at that time
  calories_burned  numeric(7, 2) not null check (calories_burned >= 0),
  logged_at        timestamptz not null default now()
);

create index if not exists exercise_logs_user_logged_at_idx
  on public.exercise_logs (user_id, logged_at desc);

alter table public.exercise_logs enable row level security;
