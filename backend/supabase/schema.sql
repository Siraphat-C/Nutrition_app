-- =====================================================================
-- Nutrition App - Database schema (Supabase / PostgreSQL)
-- แอปพลิเคชันวิเคราะห์โภชนาการอาหารจากรูปภาพด้วยปัญญาประดิษฐ์
--
-- Authentication is done by the FastAPI server (bcrypt + JWT).
-- FastAPI connects with the service_role / secret key, which bypasses RLS.
-- RLS is enabled with NO policies, so the public anon key cannot read or
-- write any table. The Flutter app must talk to FastAPI only.
--
-- Run once in Supabase Dashboard -> SQL Editor on an empty database.
-- =====================================================================

-- ---------------------------------------------------------------------
-- roles (ตารางที่ 36)
-- ---------------------------------------------------------------------
create table public.roles (
  role_id   smallint primary key,
  role_name varchar(50) not null unique
);

insert into public.roles (role_id, role_name) values
  (1, 'admin'),
  (2, 'user');

-- ---------------------------------------------------------------------
-- users (ตารางที่ 37)
-- password_hash stores a bcrypt hash, never the plain password.
-- ---------------------------------------------------------------------
create table public.users (
  user_id       integer generated always as identity primary key,
  role_id       smallint not null default 2 references public.roles (role_id),
  email         varchar(100) not null unique,
  username      varchar(50) not null unique,
  password_hash varchar(255) not null,
  token_version integer not null default 0,  -- +1 on logout / password change
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- user_profiles (ตารางที่ 38) - one row per user
-- activity_level: 1 = sedentary ... 5 = extra active
-- goal: lose / maintain / gain
-- daily_calories is calculated by the FastAPI server (nutrition.py)
-- ---------------------------------------------------------------------
create table public.user_profiles (
  profile_id         integer generated always as identity primary key,
  user_id            integer not null unique references public.users (user_id) on delete cascade,
  gender             varchar(10) check (gender in ('male', 'female')),
  birth_date         date check (birth_date <= current_date),
  weight             numeric(5, 2) check (weight > 0 and weight < 400),  -- kg
  height             numeric(5, 2) check (height > 0 and height < 300),  -- cm
  activity_level     smallint check (activity_level between 1 and 5),
  goal               varchar(50) check (goal in ('lose', 'maintain', 'gain')),
  daily_calories     numeric(7, 2),  -- kcal
  target_weight      numeric(5, 2) check (target_weight > 0 and target_weight < 400),  -- kg (migration 007)
  target_date        date,           -- วันที่ตั้งใจถึงน้ำหนักเป้าหมาย
  target_start_weight numeric(5, 2) check (target_start_weight > 0 and target_start_weight < 400),  -- kg ตอนตั้งเป้า (migration 008)
  target_set_at      date,           -- วันที่ตั้งเป้า
  calculated_at      timestamptz,
  updated_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- foods (ตารางที่ 39) - calories per 100 g
-- food_name must match the class name of the YOLO model exactly.
-- The server adds a row for every new model class on startup (no Thai name / calories yet).
-- ---------------------------------------------------------------------
create table public.foods (
  food_id               integer generated always as identity primary key,
  food_name             varchar(100) not null unique,
  food_name_th          varchar(100),                         -- ชื่อไทยที่แสดงในแอป (migration 006)
  calories_per_100g     numeric(7, 2) check (calories_per_100g >= 0),  -- ว่าง = แอดมินยังไม่เติม
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- saved_menu (ตารางที่ 40) - meals the user saved (used by /api/logs)
-- ---------------------------------------------------------------------
create table public.saved_menu (
  saved_menu_id      integer generated always as identity primary key,
  user_id            integer not null references public.users (user_id) on delete cascade,
  food_id            integer not null references public.foods (food_id) on delete restrict,
  image_path         varchar(255),
  estimated_weight   numeric(7, 2) not null check (estimated_weight > 0),  -- g
  is_manual_weight   boolean not null default false,  -- true when user typed the weight
  total_calories     numeric(8, 2) not null,
  meal_type          varchar(20) not null default 'snack'
                     constraint saved_menu_meal_type_check
                     check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  saved_at           timestamptz not null default now()
);

create index saved_menu_user_saved_at_idx on public.saved_menu (user_id, saved_at desc);

-- ---------------------------------------------------------------------
-- weight_logs - weight history for the dashboard graph and alerts
-- ---------------------------------------------------------------------
create table public.weight_logs (
  weight_log_id integer generated always as identity primary key,
  user_id       integer not null references public.users (user_id) on delete cascade,
  weight        numeric(5, 2) not null check (weight > 0 and weight < 400),  -- kg
  logged_at     timestamptz not null default now()
);

create index weight_logs_user_logged_at_idx on public.weight_logs (user_id, logged_at desc);

-- ---------------------------------------------------------------------
-- exercise_logs - exercise sessions; calories_burned = MET x weight_kg x hours
-- ---------------------------------------------------------------------
create table public.exercise_logs (
  exercise_log_id  integer generated always as identity primary key,
  user_id          integer not null references public.users (user_id) on delete cascade,
  activity         varchar(50) not null,                                              -- key in exercise.py
  met              numeric(4, 1) not null check (met > 0 and met <= 25),
  duration_minutes integer not null check (duration_minutes between 1 and 600),
  weight_kg        numeric(5, 2) not null check (weight_kg > 0 and weight_kg < 400),  -- body weight at that time
  calories_burned  numeric(7, 2) not null check (calories_burned >= 0),
  logged_at        timestamptz not null default now()
);

create index exercise_logs_user_logged_at_idx on public.exercise_logs (user_id, logged_at desc);

-- ---------------------------------------------------------------------
-- food_logs - OLD, used by the current /api/logs endpoints.
-- Not in the report and no longer used by the API (replaced by saved_menu). Drop when ready.
-- ---------------------------------------------------------------------
create table public.food_logs (
  log_id    integer generated always as identity primary key,
  user_id   integer not null references public.users (user_id) on delete cascade,
  food_id   integer not null references public.foods (food_id) on delete restrict,
  meal_type varchar(20) not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  logged_at timestamptz not null default now()
);

create index food_logs_user_logged_at_idx on public.food_logs (user_id, logged_at desc);

-- ---------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger user_profiles_set_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

create trigger foods_set_updated_at
  before update on public.foods
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security: on, with no policies.
-- service_role (FastAPI) bypasses RLS; anon/authenticated keys get nothing.
-- ---------------------------------------------------------------------
alter table public.roles         enable row level security;
alter table public.users         enable row level security;
alter table public.user_profiles enable row level security;
alter table public.foods         enable row level security;
alter table public.saved_menu    enable row level security;
alter table public.food_logs     enable row level security;
alter table public.weight_logs   enable row level security;
alter table public.exercise_logs enable row level security;
