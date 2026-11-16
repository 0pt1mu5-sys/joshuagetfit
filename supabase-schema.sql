-- GetFit schema. Safe to re-run (also upgrades the earlier version). Supabase: SQL Editor > New query > Run

create table if not exists public.profiles (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  sex text, age int, height numeric, weight numeric, activity numeric, goal text,
  tdee int, target int, updated_at timestamptz default now()
);
alter table public.profiles
  add column if not exists target_weight numeric,
  add column if not exists diet text,
  add column if not exists allergies text,
  add column if not exists ai_ok boolean default false,
  add column if not exists fast_ok boolean default false;

create table if not exists public.fasts (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  protocol text not null, goal_hours numeric not null,
  started_at timestamptz not null default now(), ended_at timestamptz
);

create table if not exists public.meals (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null, name text not null, kcal int not null check (kcal >= 0),
  protein numeric default 0, carbs numeric default 0, fat numeric default 0,
  created_at timestamptz default now()
);
alter table public.meals
  add column if not exists meal_type text default 'snack',
  add column if not exists source text default 'user';  -- 'database' (estimate) or 'user'

create table if not exists public.water_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null, ml int not null check (ml > 0), created_at timestamptz default now()
);
create table if not exists public.weights (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null, kg numeric(5,1) not null, waist numeric(5,1), created_at timestamptz default now()
);
create table if not exists public.workouts (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  day date not null, type text not null, minutes int not null, kcal int, notes text,
  created_at timestamptz default now()
);

create index if not exists meals_user_day on public.meals (user_id, day);
create index if not exists water_user_day on public.water_logs (user_id, day);
create index if not exists weights_user_day on public.weights (user_id, day);
create index if not exists workouts_user_day on public.workouts (user_id, day);
create index if not exists fasts_user_start on public.fasts (user_id, started_at desc);

-- Row Level Security: each user only sees and changes their own rows
do $$
declare t text;
begin
  foreach t in array array['profiles','fasts','meals','water_logs','weights','workouts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
    execute format('drop policy if exists "own %s" on public.%I', t, t);
    execute format('create policy "own rows" on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;
