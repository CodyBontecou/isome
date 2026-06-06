import { describe, expect, it } from "vitest";
import {
  computeNextFire,
  getZonedParts,
  tzOffsetMinutes,
  zonedTimeToUtcMs,
} from "./scheduling";

function sec(iso: string): number {
  return Math.floor(new Date(iso).getTime() / 1000);
}

describe("timezone date math", () => {
  it("extracts wall-clock parts in the target zone", () => {
    const parts = getZonedParts(Date.UTC(2026, 4, 4, 12, 0), "America/Los_Angeles");
    expect(parts.year).toBe(2026);
    expect(parts.month).toBe(5);
    expect(parts.day).toBe(4);
    expect(parts.hour).toBe(5);
    expect(parts.weekday).toBe(1);
  });

  it("returns daylight-saving-aware offsets", () => {
    expect(tzOffsetMinutes("America/Los_Angeles", Date.UTC(2026, 0, 15))).toBe(-480);
    expect(tzOffsetMinutes("America/Los_Angeles", Date.UTC(2026, 6, 15))).toBe(-420);
  });

  it("converts zoned wall-clock time to UTC", () => {
    expect(new Date(zonedTimeToUtcMs(2026, 7, 15, 9, 0, "America/Los_Angeles")).toISOString())
      .toBe("2026-07-15T16:00:00.000Z");
  });
});

describe("computeNextFire", () => {
  it("fires daily today when the selected time is still ahead", () => {
    const next = computeNextFire(
      { frequency: "daily", hour: 9, minute: 0 },
      "America/Los_Angeles",
      sec("2026-05-04T12:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-04T16:00:00.000Z");
  });

  it("rolls daily schedules to tomorrow when today's slot passed", () => {
    const next = computeNextFire(
      { frequency: "daily", hour: 9, minute: 0 },
      "America/Los_Angeles",
      sec("2026-05-04T17:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-05T16:00:00.000Z");
  });

  it("fires weekly on the configured ISO weekday", () => {
    const next = computeNextFire(
      { frequency: "weekly", hour: 9, minute: 0, weekday: 3 },
      "America/Los_Angeles",
      sec("2026-05-04T12:00:00Z"),
    );
    expect(new Date(next * 1000).toISOString()).toBe("2026-05-06T16:00:00.000Z");
  });

  it("requires weekday for weekly schedules", () => {
    expect(() => computeNextFire(
      { frequency: "weekly", hour: 9, minute: 0 },
      "UTC",
      sec("2026-05-04T12:00:00Z"),
    )).toThrow();
  });
});
