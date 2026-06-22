-- =============================================================================
-- Consulting Tracker — migration v2 (additive; safe to run once on top of v1)
-- =============================================================================
-- Adds: projects, payments, recurring templates, estimates, discounts, a second
-- tax rate, per-invoice currency, mileage, expense categories, and logo support.
-- Run this in the Supabase SQL editor AFTER supabase-schema.sql.
-- =============================================================================

-- ---------------------------------------------------------------- projects
create table if not exists public.projects (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id  uuid references public.clients(id) on delete cascade,
  name       text not null,
  rate       numeric,                      -- optional project rate; falls back to client rate
  archived   boolean not null default false,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------- payments (partial payments)
create table if not exists public.payments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete cascade,
  amount     numeric not null default 0,
  paid_date  date not null default current_date,
  note       text default '',
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------- recurring templates
create table if not exists public.recurring_templates (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id      uuid references public.clients(id) on delete cascade,
  name           text default '',
  cadence        text default 'monthly',      -- weekly | monthly | quarterly
  line_items     jsonb default '[]'::jsonb,
  tax_rate       numeric default 0,
  notes          text default '',
  last_generated date,
  created_at     timestamptz default now()
);

-- ---------------------------------------------------------------- new columns
alter table public.time_entries add column if not exists project_id uuid references public.projects(id) on delete set null;

alter table public.expenses add column if not exists project_id uuid references public.projects(id) on delete set null;
alter table public.expenses add column if not exists category text default '';
alter table public.expenses add column if not exists miles numeric;            -- when set, this is a mileage expense

alter table public.invoices add column if not exists doc_type        text default 'invoice';  -- invoice | estimate
alter table public.invoices add column if not exists currency        text default 'USD';
alter table public.invoices add column if not exists discount        numeric default 0;
alter table public.invoices add column if not exists discount_is_pct boolean default true;
alter table public.invoices add column if not exists tax2_rate       numeric default 0;

alter table public.settings add column if not exists tax_name        text default 'Tax';
alter table public.settings add column if not exists tax2_name       text default '';
alter table public.settings add column if not exists tax2_rate       numeric default 0;
alter table public.settings add column if not exists mileage_rate    numeric default 0.67;
alter table public.settings add column if not exists estimate_prefix text default 'EST-';
alter table public.settings add column if not exists estimate_next   integer default 1;

-- ---------------------------------------------------------------- indexes
create index if not exists idx_projects_client on public.projects(user_id, client_id);
create index if not exists idx_payments_invoice on public.payments(invoice_id);
create index if not exists idx_recurring_user on public.recurring_templates(user_id);

-- ---------------------------------------------------------------- RLS for new tables
alter table public.projects            enable row level security;
alter table public.payments            enable row level security;
alter table public.recurring_templates enable row level security;

do $$
declare t text;
begin
  foreach t in array array['projects','payments','recurring_templates']
  loop
    execute format('drop policy if exists own_rows on public.%I;', t);
    execute format(
      'create policy own_rows on public.%I
         for all using (user_id = auth.uid()) with check (user_id = auth.uid());', t);
  end loop;
end $$;
