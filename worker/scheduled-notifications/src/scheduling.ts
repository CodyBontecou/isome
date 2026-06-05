/**
 * Compute the next fire time for an export schedule as UTC unix seconds.
 *
 * Handles IANA timezones via Intl, including DST transitions. Daily schedules
 * fire today at hour:minute or tomorrow if that has passed. Weekly schedules
 * fire on ISO weekday 1 = Mon … 7 = Sun.
 */

export type Frequency = "daily" | "weekly";

export interface Schedule {
  frequency: Frequency;
  hour: number;
  minute: number;
  weekday?: number;
}

export interface ZonedParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  weekday: number;
}

const ISO_WEEKDAY: Record<string, number> = {
  Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7,
};

export function getZonedParts(utcMs: number, tz: string): ZonedParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    weekday: "short",
    hourCycle: "h23",
  }).formatToParts(new Date(utcMs));
  const get = (type: string) => parts.find((p) => p.type === type)!.value;
  return {
    year: Number(get("year")),
    month: Number(get("month")),
    day: Number(get("day")),
    hour: Number(get("hour")),
    minute: Number(get("minute")),
    second: Number(get("second")),
    weekday: ISO_WEEKDAY[get("weekday")] ?? 0,
  };
}

export function tzOffsetMinutes(tz: string, utcMs: number): number {
  const z = getZonedParts(utcMs, tz);
  const asUtc = Date.UTC(z.year, z.month - 1, z.day, z.hour, z.minute, z.second);
  return Math.round((asUtc - utcMs) / 60000);
}

export function zonedTimeToUtcMs(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  tz: string,
): number {
  let guess = Date.UTC(year, month - 1, day, hour, minute);
  const offset1 = tzOffsetMinutes(tz, guess);
  guess -= offset1 * 60000;
  const offset2 = tzOffsetMinutes(tz, guess);
  if (offset2 !== offset1) guess -= (offset2 - offset1) * 60000;
  return guess;
}

export function computeNextFire(schedule: Schedule, tz: string, nowSec: number): number {
  const nowMs = nowSec * 1000;
  const z = getZonedParts(nowMs, tz);

  let candidate = zonedTimeToUtcMs(z.year, z.month, z.day, schedule.hour, schedule.minute, tz);
  let daysToAdd = 0;

  if (schedule.frequency === "daily") {
    if (candidate <= nowMs) daysToAdd = 1;
  } else {
    const target = schedule.weekday;
    if (target === undefined || target < 1 || target > 7) {
      throw new Error("Weekly schedule requires weekday in [1,7]");
    }
    daysToAdd = (target - z.weekday + 7) % 7;
    if (daysToAdd === 0 && candidate <= nowMs) daysToAdd = 7;
  }

  if (daysToAdd > 0) {
    candidate = zonedTimeToUtcMs(
      z.year,
      z.month,
      z.day + daysToAdd,
      schedule.hour,
      schedule.minute,
      tz,
    );
  }

  return Math.floor(candidate / 1000);
}
