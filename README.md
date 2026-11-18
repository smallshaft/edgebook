# edgebook

Track how good you actually are at prediction-market trading. Paste a Polymarket wallet address and see P&L, accuracy, calibration, category breakdowns, and where you rank.

Read-only by design: edgebook only ever asks for a **public wallet address**. It never asks for or stores private keys, seed phrases, or API keys that can trade.

## Stack (all free tiers)

- **Next.js 16** (App Router) + TypeScript + Tailwind CSS 4
- **Supabase**: Postgres database + Auth (email magic link + Google)
- **Vercel**: hosting
- **Resend**: email (sign-in links via Supabase SMTP now, alerts in phase 6)
- **Supabase pg_cron**: scheduler for alerts and benchmark jobs (see "Decisions" below)
- **Vitest**: unit tests (all money math gets tests)

## Setup

Follow **[SETUP.md](SETUP.md)**. It's click-by-click, browser only, about 30 minutes. It covers Supabase, Vercel, Google login, and testing.

Developer commands: `npm install`, `npm run dev`, `npm test`, `npm run build`.

## Project layout

```
src/
  app/                 pages and routes
    login/             sign-in page (Google + email link)
    auth/callback/     where Google / email links land; creates the session
    auth/signout/      sign out
    dashboard/         signed-in home (private)
  lib/
    supabase/          database clients: browser, server (as the user), admin (secret key), proxy
    plans.ts           plan + feature-flag checks for a future paid tier
    venues.ts          supported venues (Polymarket now, Kalshi in v2)
  proxy.ts             runs before each request: refreshes the session, guards private pages
supabase/migrations/   database schema (run in the Supabase SQL editor)
```

## Data model in one paragraph

Every market, trader account, trade, and position has a `venue` column pointing at a small `venues` table (only `polymarket` today). A **trader account** is one wallet on one venue, shared by everyone, so a wallet watched by 50 users is synced once. Users link to trader accounts through `user_accounts` (my wallets) and `watchlist` (wallets I follow). `trades` stores every position-changing event, including non-trade events like redeems and merges that matter for P&L. `positions` and `account_metrics` are caches computed by our own P&L engine so pages load fast. `benchmark_runs` / `benchmark_members` hold the percentile sample. Row Level Security keeps personal rows private and makes public market data read-only to users; only server code with the secret key writes synced data.

## Paid-tier hooks

`profiles.plan` is `free` or `pro`. `src/lib/plans.ts` has `hasFeature(plan, feature)` and `limitFor(plan, limit)`. During launch `FREE_LAUNCH = true` unlocks everything. To start charging: set it to `false` and have a Stripe webhook update `profiles.plan`. Users can't change their own plan (there's no update policy on `profiles`).

## Decisions and research notes

**Scheduler (alerts every 5–15 min, benchmark daily).** Checked Nov 2026:
- Vercel Hobby cron: **once per day max**, fires anywhere within the hour. Not usable for alerts.
- GitHub Actions cron: every 5 min minimum, but runs can be delayed or dropped under load, and the private-repo free allowance (about 2,000 Linux minutes/month) wouldn't cover a job every 10 minutes (~4,300 runs/month). Free on public repos.
- **Chosen: Supabase pg_cron + pg_net**, which runs inside our database on a minute-level schedule and calls a protected Vercel API route (`/api/cron/...`) every 10 minutes. Free, no repo-visibility dependency, and the regular activity also stops Supabase from auto-pausing the free project after 7 idle days. Tradeoff: each run is limited by Vercel's function time limit, so jobs work in small batches. Fallback if needed: a free external pinger such as cron-job.org hitting the same route.

**Polymarket APIs.** Data API (`data-api.polymarket.com`) now has a **v2** with cursor pagination (v1's `offset` stopped at 10,000 rows), which we'll use. Rate limits are per IP and generous (e.g. v2 trades 300 req / 10 s, Gamma markets 300 req / 10 s), and over-limit requests are throttled rather than rejected. Users must paste their **proxy wallet** (the address in their Polymarket profile URL), not their signing key.

**Polymarket Terms of Use.** Section 4.2 bans scraping tools and bars commercially exploiting or redistributing Polymarket "Data" without written agreement. A free app showing traders their own stats via the public API is lower-risk; **before charging for a paid tier, contact Polymarket (they mention a builder program) for written permission.**

**Polymarket US.** It's a separate CFTC-regulated exchange (QCX LLC) with its own API (`api.polymarket.us`). Portfolio data (positions, trades) needs a verified account's own API key; there's no public wallet address to look up. So US accounts **can't** be tracked by pasting an address like global Polymarket. Supporting them would mean users handing us API keys, which conflicts with our "nothing that can trade" rule unless read-only keys exist (not confirmed yet). Treat it like a separate venue for a later version.

## Status

### Done
- [x] **Phase 1**: Next.js + Tailwind (dark, mobile-first), venue-agnostic Supabase schema with RLS, email + Google login, protected dashboard, plan/feature-flag hooks, tests

### Next
- [ ] **Phase 2**: wallet connect, sync trades into the database, trade log (search, filter, CSV)
- [ ] Phase 3: P&L engine (realized/unrealized, fees, partial closes, resolution) + chart
- [ ] Phase 4: accuracy, calibration (Brier), category breakdown
- [ ] Phase 5: benchmark sample job + percentile ranks
- [ ] Phase 6: watchlist, leaderboard, alerts
- [ ] Phase 7: polish, sub-30-second onboarding, empty/loading/error states
