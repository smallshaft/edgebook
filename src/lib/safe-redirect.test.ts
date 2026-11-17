import { describe, expect, it } from "vitest";
import { safeNextPath } from "./safe-redirect";

describe("safeNextPath", () => {
  it("keeps local paths", () => expect(safeNextPath("/dashboard/x")).toBe("/dashboard/x"));
  it("rejects other sites", () => {
    expect(safeNextPath("https://evil.com")).toBe("/dashboard");
    expect(safeNextPath("//evil.com")).toBe("/dashboard");
    expect(safeNextPath("/\\evil.com")).toBe("/dashboard");
  });
  it("falls back when empty", () => expect(safeNextPath(null)).toBe("/dashboard"));
});
