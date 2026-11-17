// Plan + feature-flag hooks for a future paid tier.
// Everything is free at launch: FREE_LAUNCH = true unlocks every feature for everyone.
// Later, flip FREE_LAUNCH to false, wire Stripe to set profiles.plan = 'pro', and
// these checks start gating features with no other code changes.

export type Plan = "free" | "pro";

export type Feature =
  | "unlimited_watchlist"
  | "alerts"
  | "percentile_details"
  | "csv_export"
  | "multiple_wallets";

export const FREE_LAUNCH = true;

/** Which plans include each feature once the paywall is on. */
const FEATURE_PLANS: Record<Feature, Plan[]> = {
  unlimited_watchlist: ["pro"],
  alerts: ["pro"],
  percentile_details: ["pro"],
  csv_export: ["free", "pro"],
  multiple_wallets: ["free", "pro"],
};

/** Numeric limits per plan (used when a feature is "limited" rather than on/off). */
export const PLAN_LIMITS: Record<Plan, { watchlist: number; wallets: number }> = {
  free: { watchlist: 5, wallets: 3 },
  pro: { watchlist: Infinity, wallets: 20 },
};

export function normalizePlan(plan: string | null | undefined): Plan {
  return plan === "pro" ? "pro" : "free";
}

export function hasFeature(
  plan: string | null | undefined,
  feature: Feature,
  opts: { freeLaunch?: boolean } = {},
): boolean {
  if (opts.freeLaunch ?? FREE_LAUNCH) return true;
  return FEATURE_PLANS[feature].includes(normalizePlan(plan));
}

export function limitFor(
  plan: string | null | undefined,
  limit: keyof (typeof PLAN_LIMITS)["free"],
  opts: { freeLaunch?: boolean } = {},
): number {
  if (opts.freeLaunch ?? FREE_LAUNCH) return PLAN_LIMITS.pro[limit];
  return PLAN_LIMITS[normalizePlan(plan)][limit];
}
