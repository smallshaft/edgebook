import { describe, expect, it } from "vitest";
import { hasFeature, limitFor, normalizePlan } from "./plans";

describe("plans / feature flags", () => {
  it("unlocks everything during the free launch", () => {
    expect(hasFeature("free", "alerts", { freeLaunch: true })).toBe(true);
    expect(limitFor("free", "watchlist", { freeLaunch: true })).toBe(Infinity);
  });

  it("gates pro features once the paywall is on", () => {
    expect(hasFeature("free", "alerts", { freeLaunch: false })).toBe(false);
    expect(hasFeature("pro", "alerts", { freeLaunch: false })).toBe(true);
    expect(hasFeature("free", "csv_export", { freeLaunch: false })).toBe(true);
  });

  it("applies per-plan limits", () => {
    expect(limitFor("free", "watchlist", { freeLaunch: false })).toBe(5);
    expect(limitFor("pro", "watchlist", { freeLaunch: false })).toBe(Infinity);
  });

  it("treats unknown or missing plans as free", () => {
    expect(normalizePlan(undefined)).toBe("free");
    expect(normalizePlan("enterprise")).toBe("free");
    expect(hasFeature(null, "alerts", { freeLaunch: false })).toBe(false);
  });
});
