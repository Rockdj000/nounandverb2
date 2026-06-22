-- =============================================================================
-- Meditation app — schema (additive; safe to run once on the existing project)
-- =============================================================================
-- Adds per-user custom breathing patterns and a session log. Same Supabase
-- project as the Invoice app. Run this in the Supabase SQL editor. Email auth
-- must be enabled (it already is for the Invoice app).
-- =============================================================================

-- ---------------------------------------------------------------- breathing patterns
create table if not exists public.breathing_patterns (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name       text not null,
  inhale     numeric not null,            -- seconds
  hold_in    numeric not null default 0,  -- seconds held after inhale
  exhale     numeric not null,            -- seconds
  hold_out   numeric not null default 0,  -- seconds held after exhale
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------- session log
create table if not exists public.meditation_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users(id) on delete cascade,
  mode             text not null,                 -- 'breathe' | 'timer'
  pattern_name     text default '',
  duration_seconds integer not null default 0,
  created_at       timestamptz default now()
);

-- ---------------------------------------------------------------- indexes
create index if not exists idx_breathing_patterns_user on public.breathing_patterns(user_id, created_at);
create index if not exists idx_meditation_sessions_user on public.meditation_sessions(user_id, created_at);

-- ---------------------------------------------------------------- RLS
alter table public.breathing_patterns   enable row level security;
alter table public.meditation_sessions  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['breathing_patterns','meditation_sessions']
  loop
    execute format('drop policy if exists own_rows on public.%I;', t);
    execute format(
      'create policy own_rows on public.%I
         for all using (user_id = auth.uid()) with check (user_id = auth.uid());', t);
  end loop;
end $$;
