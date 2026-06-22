-- =============================================================================
-- Consulting Time / Expense / Invoice Tracker — Supabase schema
-- =============================================================================
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
-- Every table is scoped to the authenticated user via Row-Level Security so the
-- page can ship a public anon key safely: a user can only ever see their own rows.
--
-- Auth setup (Dashboard → Authentication):
--   • Providers → Email: enabled (magic link works out of the box).
--   • For local testing you may also turn OFF "Confirm email" so sign-in is instant.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- settings — one row per user; your business profile + invoice defaults.
-- ----------------------------------------------------------------------------
create table if not exists public.settings (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  business_name  text default '',
  business_email text default '',
  address        text default '',
  payment_terms  text default 'Payment due within 30 days.',
  currency       text default 'USD',
  tax_rate       numeric default 0,           -- percent, e.g. 8.5
  logo_url       text default '',
  invoice_prefix text default 'INV-',
  invoice_next   integer default 1,           -- next invoice number to assign
  updated_at     timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- clients
-- ----------------------------------------------------------------------------
create table if not exists public.clients (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name         text not null,
  email        text default '',
  address      text default '',
  default_rate numeric default 0,
  currency     text default 'USD',
  notes        text default '',
  created_at   timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- invoices  (created before time_entries/expenses so they can FK to it)
-- line_items is a snapshot taken at generation time so the invoice is immutable.
-- ----------------------------------------------------------------------------
create table if not exists public.invoices (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id      uuid references public.clients(id) on delete set null,
  invoice_number text not null,
  issue_date     date not null default current_date,
  due_date       date,
  status         text not null default 'draft',  -- draft | sent | paid
  tax_rate       numeric default 0,
  notes          text default '',
  line_items     jsonb default '[]'::jsonb,
  subtotal       numeric default 0,
  tax            numeric default 0,
  total          numeric default 0,
  created_at     timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- time_entries — invoice_id is null until the entry is billed on an invoice.
-- ----------------------------------------------------------------------------
create table if not exists public.time_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id   uuid references public.clients(id) on delete set null,
  entry_date  date not null default current_date,
  description text default '',
  hours       numeric not null default 0,
  rate        numeric not null default 0,
  billable    boolean not null default true,
  invoice_id  uuid references public.invoices(id) on delete set null,
  created_at  timestamptz default now()
);

-- ----------------------------------------------------------------------------
-- expenses
-- ----------------------------------------------------------------------------
create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id    uuid references public.clients(id) on delete set null,
  entry_date   date not null default current_date,
  description  text default '',
  amount       numeric not null default 0,
  billable     boolean not null default true,
  invoice_id   uuid references public.invoices(id) on delete set null,
  created_at   timestamptz default now()
);

-- Helpful indexes for the common filters.
create index if not exists idx_time_user_client on public.time_entries(user_id, client_id);
create index if not exists idx_time_invoice     on public.time_entries(invoice_id);
create index if not exists idx_exp_user_client  on public.expenses(user_id, client_id);
create index if not exists idx_exp_invoice      on public.expenses(invoice_id);
create index if not exists idx_inv_user_client  on public.invoices(user_id, client_id);

-- =============================================================================
-- Row-Level Security
-- =============================================================================
alter table public.settings     enable row level security;
alter table public.clients      enable row level security;
alter table public.invoices     enable row level security;
alter table public.time_entries enable row level security;
alter table public.expenses     enable row level security;

-- A single "own rows only" policy per table covers select/insert/update/delete.
do $$
declare t text;
begin
  foreach t in array array['settings','clients','invoices','time_entries','expenses']
  loop
    execute format('drop policy if exists own_rows on public.%I;', t);
    execute format(
      'create policy own_rows on public.%I
         for all
         using (user_id = auth.uid())
         with check (user_id = auth.uid());', t);
  end loop;
end $$;
