-- edgebook initial schema
-- Venue-agnostic: every market, trader account, trade and position carries a `venue`.
-- Adding Kalshi later = add 'kalshi' to the venue check + write a Kalshi sync adapter.
-- Nothing in this file assumes Polymarket.

-- ---------------------------------------------------------------------------
-- Venues
-- ---------------------------------------------------------------------------
-- A tiny lookup table instead of a Postgres enum: adding a venue is one INSERT,
-- not an ALTER TYPE migration.
create table public.venues (
  id          text primary key,          -- 'polymarket', later 'kalshi'
  name        text not null,
  enabled     boolean not null default true
);

insert into public.venues (id, name) values ('polymarket', 'Polymarket');

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
-- Supabase Auth owns auth.users. We keep our own per-user row for app data.
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  plan        text not null default 'free' check (plan in ('free', 'pro')),
  created_at  timestamptz not null default now()
);

-- Auto-create a profile whenever someone signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Trader accounts (a wallet on Polymarket, an account on Kalshi, ...)
-- ---------------------------------------------------------------------------
-- One row per venue account, shared by everyone: if 50 users watch the same
-- wallet we sync it once. Users link to these via user_accounts / watchlist.
create table public.trader_accounts (
  id               uuid primary key default gen_random_uuid(),
  venue            text not null references public.venues (id),
  external_id      text not null,        -- Polymarket: lowercase 0x proxy-wallet address
  display_name     text,                 -- public username/pseudonym if the venue exposes one
  profile_image    text,
  last_synced_at   timestamptz,
  sync_cursor      jsonb,                -- venue-specific "where did we stop" marker
  sync_status      text not null default 'never' check (sync_status in ('never', 'syncing', 'ok', 'error')),
  sync_error       text,
  is_benchmark     boolean not null default false,  -- part of the percentile sample (phase 5)
  created_at       timestamptz not null default now(),
  unique (venue, external_id)
);

-- Wallets a user has saved as "mine".
create table public.user_accounts (
  user_id            uuid not null references public.profiles (id) on delete cascade,
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  label              text,
  is_primary         boolean not null default false,
  created_at         timestamptz not null default now(),
  primary key (user_id, trader_account_id)
);

-- Wallets a user is watching (someone else's).
create table public.watchlist (
  user_id            uuid not null references public.profiles (id) on delete cascade,
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  alerts_email       boolean not null default true,
  alerts_in_app      boolean not null default true,
  created_at         timestamptz not null default now(),
  primary key (user_id, trader_account_id)
);

-- ---------------------------------------------------------------------------
-- Markets
-- ---------------------------------------------------------------------------
create table public.markets (
  id                 uuid primary key default gen_random_uuid(),
  venue              text not null references public.venues (id),
  external_id        text not null,      -- Polymarket: conditionId. Kalshi: market ticker.
  event_external_id  text,               -- Polymarket event id / Kalshi event ticker
  slug               text,
  title              text not null,
  category           text,               -- our normalized category: politics, sports, crypto, ...
  tags               text[] not null default '{}',  -- raw venue tags
  outcomes           text[] not null default '{}',  -- e.g. {Yes,No} or {Lakers,Celtics}
  image              text,
  end_date           timestamptz,
  closed             boolean not null default false,
  resolved           boolean not null default false,
  winning_outcome    text,               -- set when resolved
  resolved_at        timestamptz,
  metadata_synced_at timestamptz,
  created_at         timestamptz not null default now(),
  unique (venue, external_id)
);

create index markets_category_idx on public.markets (venue, category);

-- ---------------------------------------------------------------------------
-- Trades (fills + other position-changing activity)
-- ---------------------------------------------------------------------------
-- `kind` matters for P&L: a REDEEM (cashing a winning share for $1) or a MERGE
-- (turning a YES+NO pair back into $1) changes a position without being a trade.
create table public.trades (
  id                 uuid primary key default gen_random_uuid(),
  venue              text not null references public.venues (id),
  external_id        text not null,      -- venue-unique id (Polymarket: tx hash + extra key)
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  market_id          uuid references public.markets (id),
  market_external_id text not null,      -- kept even if market metadata isn't synced yet
  kind               text not null default 'trade'
                       check (kind in ('trade', 'redeem', 'merge', 'split', 'convert', 'reward', 'other')),
  outcome            text,               -- 'Yes' / 'No' / named outcome
  outcome_index      int,
  side               text check (side in ('buy', 'sell')),
  price              numeric(12, 6),     -- per share, 0..1 dollars
  size               numeric(20, 6),     -- shares
  usdc_size          numeric(20, 6),     -- dollars moved
  fee                numeric(20, 6) not null default 0,
  traded_at          timestamptz not null,
  raw                jsonb,              -- original API row, for debugging/backfills
  created_at         timestamptz not null default now(),
  unique (venue, external_id)
);

create index trades_account_time_idx on public.trades (trader_account_id, traded_at desc);
create index trades_market_idx on public.trades (market_id);

-- ---------------------------------------------------------------------------
-- Positions (computed by our P&L engine from trades, cached for fast pages)
-- ---------------------------------------------------------------------------
create table public.positions (
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  venue              text not null references public.venues (id),
  market_id          uuid not null references public.markets (id),
  outcome            text not null,
  shares             numeric(20, 6) not null default 0,   -- currently held
  avg_cost           numeric(12, 6) not null default 0,   -- weighted-average cost per share
  cost_basis         numeric(20, 6) not null default 0,
  realized_pnl       numeric(20, 6) not null default 0,
  unrealized_pnl     numeric(20, 6) not null default 0,
  fees_paid          numeric(20, 6) not null default 0,
  current_price      numeric(12, 6),
  status             text not null default 'open' check (status in ('open', 'closed', 'resolved')),
  updated_at         timestamptz not null default now(),
  primary key (trader_account_id, market_id, outcome)
);

-- ---------------------------------------------------------------------------
-- Cached per-account metrics (P&L, ROI, accuracy, ...) - filled in phases 3-5
-- ---------------------------------------------------------------------------
create table public.account_metrics (
  trader_account_id  uuid primary key references public.trader_accounts (id) on delete cascade,
  venue              text not null references public.venues (id),
  total_pnl          numeric(20, 6),
  realized_pnl       numeric(20, 6),
  unrealized_pnl     numeric(20, 6),
  volume             numeric(20, 6),
  roi                numeric(12, 6),
  win_rate           numeric(8, 6),
  brier_score        numeric(8, 6),
  resolved_positions int,
  trade_count        int,
  computed_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Benchmark (percentile sample) - phase 5
-- ---------------------------------------------------------------------------
create table public.benchmark_runs (
  id           uuid primary key default gen_random_uuid(),
  venue        text not null references public.venues (id),
  sample_size  int not null default 0,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  notes        text
);

create table public.benchmark_members (
  run_id             uuid not null references public.benchmark_runs (id) on delete cascade,
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  source             text not null check (source in ('leaderboard', 'random_active')),
  weight             numeric(12, 6) not null default 1,   -- corrects for over-sampling top traders
  total_pnl          numeric(20, 6),
  roi                numeric(12, 6),
  win_rate           numeric(8, 6),
  volume             numeric(20, 6),
  primary key (run_id, trader_account_id)
);

-- ---------------------------------------------------------------------------
-- Alerts - phase 6
-- ---------------------------------------------------------------------------
create table public.alerts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  trader_account_id  uuid not null references public.trader_accounts (id) on delete cascade,
  trade_id           uuid references public.trades (id) on delete cascade,
  message            text not null,
  read_at            timestamptz,
  emailed_at         timestamptz,
  created_at         timestamptz not null default now()
);

create index alerts_user_idx on public.alerts (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
-- Rule of thumb:
--   * Personal rows (profile, saved wallets, watchlist, alerts): only the owner.
--   * Public market data (markets, trades, positions, metrics, benchmark): any
--     signed-in user can read; only the server (secret key) can write.
-- The server-side secret key bypasses RLS, so sync jobs can write freely.

alter table public.venues            enable row level security;
alter table public.profiles          enable row level security;
alter table public.trader_accounts   enable row level security;
alter table public.user_accounts     enable row level security;
alter table public.watchlist         enable row level security;
alter table public.markets           enable row level security;
alter table public.trades            enable row level security;
alter table public.positions         enable row level security;
alter table public.account_metrics   enable row level security;
alter table public.benchmark_runs    enable row level security;
alter table public.benchmark_members enable row level security;
alter table public.alerts            enable row level security;

-- Public-data tables: readable by anyone signed in.
create policy "read venues"            on public.venues            for select to authenticated using (true);
create policy "read trader accounts"   on public.trader_accounts   for select to authenticated using (true);
create policy "read markets"           on public.markets           for select to authenticated using (true);
create policy "read trades"            on public.trades            for select to authenticated using (true);
create policy "read positions"         on public.positions         for select to authenticated using (true);
create policy "read account metrics"   on public.account_metrics   for select to authenticated using (true);
create policy "read benchmark runs"    on public.benchmark_runs    for select to authenticated using (true);
create policy "read benchmark members" on public.benchmark_members for select to authenticated using (true);

-- Profiles: read your own. Users can't change their own plan (no update policy);
-- plan changes go through the server (later: a Stripe webhook).
create policy "read own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

-- Saved wallets.
create policy "read own wallets"   on public.user_accounts for select to authenticated using ((select auth.uid()) = user_id);
create policy "add own wallets"    on public.user_accounts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own wallets" on public.user_accounts for update to authenticated using ((select auth.uid()) = user_id);
create policy "remove own wallets" on public.user_accounts for delete to authenticated using ((select auth.uid()) = user_id);

-- Watchlist.
create policy "read own watchlist"   on public.watchlist for select to authenticated using ((select auth.uid()) = user_id);
create policy "add to own watchlist" on public.watchlist for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "update own watchlist" on public.watchlist for update to authenticated using ((select auth.uid()) = user_id);
create policy "remove from own watchlist" on public.watchlist for delete to authenticated using ((select auth.uid()) = user_id);

-- Alerts: read + mark as read.
create policy "read own alerts"   on public.alerts for select to authenticated using ((select auth.uid()) = user_id);
create policy "update own alerts" on public.alerts for update to authenticated using ((select auth.uid()) = user_id);
